// Keyboard example for Xilinx XUP Blackboard rev D (keyboard.sv)
// Jason Losh
//
// 4x4 matrix keyboard
//   COL[3:0] on GPIO[1,0,4,5]
//   ROW[3:0] on GPIO[6,7,3,2]
//   include keyboard_pullups.xdc to enable pullups on rows
// Reset
//   Reset on PB0
// Clear code ready flag
//   Clear code ready request on PB1

module keyboard(
    input CLK100,           // 100 MHz clock input
    output [9:0] LED,       // RGB1, RGB0, LED 9..0 placed from left to right
    output [2:0] RGB0,      
    output [2:0] RGB1,
    output [3:0] SS_ANODE,   // Anodes 3..0 placed from left to right
    output [7:0] SS_CATHODE, // Bit order: DP, G, F, E, D, C, B, A
    input [11:0] SW,         // SWs 11..0 placed from left to right
    input [3:0] PB,          // PBs 3..0 placed from left to right
    inout [23:0] GPIO,       // PMODA-C 1P, 1N, ... 3P, 3N order
    output [3:0] SERVO,      // Servo outputs
    output PDM_SPEAKER,      // PDM signals for mic and speaker
    input PDM_MIC_DATA,      
    output PDM_MIC_CLK,
    output ESP32_UART1_TXD,  // WiFi/Bluetooth serial interface 1
    input ESP32_UART1_RXD,
    output IMU_SCLK,         // IMU spi clk
    output IMU_SDI,          // IMU spi data input
    input IMU_SDO_AG,        // IMU spi data output (accel/gyro)
    input IMU_SDO_M,         // IMU spi data output (mag)
    output IMU_CS_AG,        // IMU cs (accel/gyro) 
    output IMU_CS_M,         // IMU cs (mag)
    input IMU_DRDY_M,        // IMU data ready (mag)
    input IMU_INT1_AG,       // IMU interrupt (accel/gyro)
    input IMU_INT_M,         // IMU interrupt (mag)
    output IMU_DEN_AG        // IMU data enable (accel/gyro)
    );
     
    // Terminate all of the unused outputs or i/o's
    // assign LED = 10'b0000000000;
    assign RGB0 = 3'b000;
    assign RGB1 = 3'b000;
    // assign SS_ANODE = 4'b0000;
    // assign SS_CATHODE = 8'b11111111;
    // assign GPIO = 24'bzzzzzzzzzzzzzzzzzzzzzzzz;
    assign SERVO = 4'b0000;
    assign PDM_SPEAKER = 1'b0;
    assign PDM_MIC_CLK = 1'b0;
    assign ESP32_UART1_TXD = 1'b0;
    assign IMU_SCLK = 1'b0;
    assign IMU_SDI = 1'b0;
    assign IMU_CS_AG = 1'b1;
    assign IMU_CS_M = 1'b1;
    assign IMU_DEN_AG = 1'b0;

    // display 4 (4x4 keyboard) on left seven segment display
    assign SS_ANODE = 4'b0111;
    assign SS_CATHODE = 8'b10011001;
    
    // drive unused GPIO lines
    assign GPIO[23:8] = 16'bzzzzzzzzzzzzzzzz;

    // use a simpler clock name
    wire clk = CLK100;
    
    // handle input metastability safely
    reg reset;
    reg pre_reset;
    always_ff @ (posedge(clk))
    begin
        pre_reset <= PB[0];
        reset <= pre_reset;
    end
    reg clear_code_ready_request;
    reg pre_clear_code_ready_request;
    always_ff @ (posedge(clk))
    begin
        pre_clear_code_ready_request <= PB[1];
        clear_code_ready_request <= pre_clear_code_ready_request;
    end
    
    // row data conditioning
    reg [3:0] row_data; 
    reg [3:0] pre_row_data;
    always @ (posedge(clk))
    begin
        pre_row_data <= {GPIO[6], GPIO[7], GPIO[3], GPIO[2]};
        row_data <= pre_row_data;
    end
 
    // column data
    wire [3:0] col_data;

    assign GPIO[5] = col_data[0];
    assign GPIO[4] = col_data[1];
    assign GPIO[0] = col_data[2];
    assign GPIO[1] = col_data[3];
    
    wire [3:0] code;
    wire code_ready; 
    wire debounce_mode;
    key4x4 kb(.clk(clk), 
           .reset(reset), 
           .rows(row_data), 
           .cols(col_data), 
           .code(code), 
           .code_ready(code_ready),
           .clear_code_ready_request(clear_code_ready_request),
           .debounce_mode(debounce_mode));
    
    assign LED = {code, 4'b0, debounce_mode, code_ready};
endmodule

// While this example includes this modules in the keyboard.sv file,
// it is best practice to put each module in a separate file with
// a filename matching the module name

module key4x4(
    input clk,
    input reset,
    input [3:0] rows,
    output reg [3:0] cols,
    output reg [3:0] code,
    output reg code_ready,
    input clear_code_ready_request,
    output reg debounce_mode); // used for debug   
    
    parameter DEBOUNCE_COUNT = 4'd10;
    parameter DEBOUNCE_CLOCKS = 19'd500000;    // 500000 * 10ns = 5ms
    parameter READ_SETTLE_CLOCKS = 19'd100000; // 100000 * 10ns = 1ms
    reg[3:0] debounce_count;
    reg[18:0] ticks;
    reg[1:0] col;
    integer i;
    
    // keyboard logic
    always_ff @ (posedge(clk))
    begin
        if (reset)
        begin
            debounce_mode <= 1;
            debounce_count <= 4'b0;
            ticks <= 19'b0;
            cols <= 4'b0000;
            code <= 4'b0000;
            code_ready <= 1'b0;
        end
        // handle request to clear write flag
        else if (clear_code_ready_request)
           code_ready <= 1'b0;
        else
        begin
            // debounce mode
            if (debounce_mode)
            begin
                if (ticks != DEBOUNCE_CLOCKS)
                    ticks <= ticks + 1;
                else
                begin
                    ticks <= 19'b0;
                    if (rows == 4'b1111)
                    begin
                        if (debounce_count == DEBOUNCE_COUNT)
                        begin
                            debounce_count <= 4'b0;
                            debounce_mode <= 1'b0;
                            col <= 2'b0;
                        end
                        else
                            debounce_count <= debounce_count + 4'b1;
                    end 
                end
            end
            // read key mode
            else
            begin
                for (i = 0; i < 4; i = i + 1)
                    cols[i] <= (col == i) ? 1'b0 : 1'bz;
                // synths into:
                // cols[0] <= (col == 0) ? 1'b0 : 1'bz;
                // cols[1] <= (col == 1) ? 1'b0 : 1'bz;
                // cols[2] <= (col == 2) ? 1'b0 : 1'bz;
                // cols[3] <= (col == 3) ? 1'b0 : 1'bz;
                
                if (ticks != READ_SETTLE_CLOCKS)
                    ticks <= ticks + 1;
                else
                begin
                    ticks <= 19'b0;
                    if (rows == 4'b1111)
                        col <= col + 4'b1;
                    else
                    begin
                        code_ready <= 1'b1;
                        debounce_mode <= 1'b1;
                        ticks <= 19'b0; // remove
                        if (rows[0] == 1'b0)
                            code <= {2'b00, col};
                        else if (rows[1] == 1'b0)
                            code <= {2'b01, col};
                        else if (rows[2] == 1'b0)
                            code <= {2'b10, col};
                        else 
                            code <= {2'b11, col};
                    end
                end
            end
        end
    end  
endmodule
