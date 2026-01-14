// RYG for Xilinx XUP Blackboard rev D (seq_logic.sv)
// Jason Losh
//
// Reset
//   Active-high reset on PB0
//   NS traffic on RGB0
//   EW traffic on RGB1

module ryg(
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
    assign LED = 10'b0000000000;
    //assign RGB0 = 3'b000;
    //assign RGB1 = 3'b000;
    assign SS_ANODE = 4'b0000;
    assign SS_CATHODE = 8'b11111111;
    assign GPIO = 24'bzzzzzzzzzzzzzzzzzzzzzzzz;
    assign GPIO[15:0] = 16'bzzzzzzzzzzzzzzzz;
    assign GPIO[23:20] = 4'bzzzz;
    assign GPIO[18] = 1'bz;
    assign SERVO = 4'b0000;
    assign PDM_SPEAKER = 1'b0;
    assign PDM_MIC_CLK = 1'b0;
    assign ESP32_UART1_TXD = 1'b0;
    assign IMU_SCLK = 1'b0;
    assign IMU_SDI = 1'b0;
    assign IMU_CS_AG = 1'b1;
    assign IMU_CS_M = 1'b1;
    assign IMU_DEN_AG = 1'b0;

    // rgb leds (3-bit BGR)
    parameter RED = 3'b001;
    parameter YELLOW = 3'b011;
    parameter GREEN = 3'b010;
    reg [2:0] NS;
    reg [2:0] EW;
    assign NS = RGB0;
    assign EW = RGB1;
    
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
    
    // 1 Hz tick
    wire sec_tick;
    reg out;
    reg [3:0] count;
    reg [2:0] three;
    divide_by_100000000 div100M(clk, sec_tick);

    // Timing
    reg [3:0] ticks;
    parameter T1 = 4'd10;
    parameter T2 = 4'd7;
    parameter T3 = 4'd2;
    parameter T4 = 4'd2;

    // FSM for traffic controller
    reg [2:0] state;
    parameter START = 3'd0;
    parameter FLOW_NS = 3'd1;
    parameter CAUT_NS = 3'd2;
    parameter STOP_NS = 3'd3;
    parameter FLOW_EW = 3'd4;
    parameter CAUT_EW = 3'd5;
    parameter STOP_EW = 3'd6;
    
    // toggle LED, inc count every second    
    always_ff @ (posedge(clk))
    begin
        if (reset)
        begin
           ticks <= 4'd0;
           state <= START;
        end
        else
        begin
            if (sec_tick)
            begin
                ticks <= ticks + 1;
                case (state)
                    START: 
                        if (ticks == T1)
                        begin
                            ticks <= 0;
                            state <= FLOW_NS;
                        end
                    FLOW_NS: 
                        if (ticks == T2)
                        begin
                            ticks <= 0;
                            state <= CAUT_NS;
                        end
                    CAUT_NS: 
                        if (ticks == T3)
                        begin
                            ticks <= 0;
                            state <= STOP_NS;
                        end
                    STOP_NS: 
                        if (ticks == T4)
                        begin
                            ticks <= 0;
                            state <= FLOW_EW;
                        end
                    FLOW_EW:
                        if (ticks == T2)
                        begin
                            ticks <= 0;
                            state <= CAUT_EW;
                        end
                    CAUT_EW: 
                        if (ticks == T3)
                        begin
                            ticks <= 0;
                            state <= STOP_EW;
                        end
                    STOP_EW: 
                        if (ticks == T4)
                        begin
                            ticks <= 0;
                            state <= FLOW_NS;
                        end
                    default: 
                        state <= START;
                endcase               
            end
        end
    end 
		
    always_comb
    begin
        if (state == FLOW_NS)
            NS = GREEN;
        else if (state == CAUT_NS)
            NS = YELLOW;
        else
            NS = RED;
        if (state == FLOW_EW)
            EW = GREEN;
        else if (state == CAUT_EW)
            EW = YELLOW;
        else
            EW = RED;
    end	  
endmodule

// While this example includes this module in the seq_logic.sv file,
// it is best practice to put each module in a separate file with
// a filename matching the module name

module divide_by_100000000(
    input clk,
    output reg out);
    
    reg [26:0] count;
    
    always_ff @ (posedge(clk))
    begin
        if (count < 27'd100000000)
        begin
           count <= count + 1;
           out <= 0;
        end
        else
        begin
            count <= 0;
            out <= 1;
        end
    end    

endmodule
