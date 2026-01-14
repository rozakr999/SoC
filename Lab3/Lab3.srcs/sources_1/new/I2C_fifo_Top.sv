`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 10/05/2025 12:49:49 AM
// Design Name: 
// Module Name: I2C_fifo_Top
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module I2C_fifo_Top
(
    input CLK100,           // 100 MHz clock input
   // output [9:0] LED,       // RGB1, RGB0, LED 9..0 placed from left to right
   output logic [9:0] LED,       // RGB1, RGB0, LED 9..0 placed from left to right
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
   // assign RGB0 = 3'b000;
    //assign RGB1 = 3'b000;
    assign SS_ANODE = 4'b0000;
    assign SS_CATHODE = 8'b11111111;
    assign GPIO = 24'bzzzzzzzzzzzzzzzzzzzzzzzz;
    assign SERVO = 4'b0000;
    assign PDM_SPEAKER = 1'b0;
    assign PDM_MIC_CLK = 1'b0;
    assign ESP32_UART1_TXD = 1'b0;
    assign IMU_SCLK = 1'b0;
    assign IMU_SDI = 1'b0;
    assign IMU_CS_AG = 1'b1;
    assign IMU_CS_M = 1'b1;
    assign IMU_DEN_AG = 1'b0;



logic pb0_q, pb0_qq, pb0_qqq; // pushbutton P0 synchronization
logic pb1_q, pb1_qq, pb1_qqq; // pushbutton P1 synchronization
logic pb2_q, pb2_qq, pb2_qqq; // pushbutton P2 synchronization
logic pb3_q, pb3_qq, pb3_qqq; // pushbutton P3 synchronization

logic mode_q, mode_qq, mode_qqq; // mode switch synchronization
logic [7:0] sw_q, sw_qq, sw_qqq; // switches 7 to 0 synchronization



//debounce logic
logic [22:0] rd_counter;
logic [22:0] wr_counter;
logic reset, clear;
logic rd_db, wr_db;
logic rd_last, wr_last;
logic rd_pulse, wr_pulse;
logic mode;
logic [7:0] data_in;
logic [7:0] rd_data;
logic [3:0] rd_index;
logic [3:0] wr_index;
logic empty, full;
logic overflow;
logic first_press; // to track the first press of pb3
logic first_press_rd; // to track the first press of pb2

assign reset = pb0_qq;
assign clear = pb1_qq; // clear overflow when pb1 pressed
assign rd_pulse = rd_db & ~rd_last; // read pulse
assign wr_pulse = wr_db & ~wr_last; // write pulse 

assign mode = mode_qqq; // mode select from switch 9
assign data_in = sw_qq; // data input from switches 7 to 0


////////////////debug LEDs
//logic [23:0] wr_stretch, rd_stretch;  // ~50ms @ 100MHz (5,000,000 cycles)



///lAST PART
/////// LED display logic
assign LED[9] = mode_qqq;
assign LED[8] = overflow;
assign LED[7:0] = (mode_qqq == 1'b0) ? rd_data : { wr_index, rd_index};
// If your RGBs are ACTIVE-HIGH (LED turns on when '1'):
assign RGB0[0] = full;     // FULL on RGB0[0]
assign RGB1[0] = empty;    // EMPTY on RGB1[0]
assign RGB0[2:1] = 2'b00;
assign RGB1[2:1] = 2'b00;


// Pushbutton synchronization
always_ff @(posedge CLK100)
begin
    {pb0_qqq, pb0_qq, pb0_q} <= {pb0_qq, pb0_q, PB[0]};
    {pb1_qqq, pb1_qq, pb1_q} <= {pb1_qq, pb1_q, PB[1]};
end

always_ff @(posedge CLK100)
begin
    {pb2_qqq, pb2_qq, pb2_q} <= {pb2_qq, pb2_q, PB[2]};
    {pb3_qqq, pb3_qq, pb3_q} <= {pb3_qq, pb3_q, PB[3]};
end


// Switch synchronization
always_ff @(posedge CLK100)
begin
    {mode_qqq, mode_qq, mode_q} <= {mode_qq, mode_q, SW[9]};
    {sw_qqq, sw_qq, sw_q} <= {sw_qq, sw_q, SW[7:0]};
end

//debounce logic

//read debounce
always_ff @(posedge CLK100)
begin
    if (reset)
    begin
        rd_counter <= 0;
        rd_db <= 0;
    end
    else
    begin 
        if (pb2_qq == 1'b1) // only debounce when pb2 is pressed
        begin
            if (rd_counter < 23'd5_000_000 && first_press_rd ) // 0.05 sec at 100 MHz
//                 rd_counter <= rd_counter + 23'd1;
                begin
                rd_counter <= rd_counter + 23'd1;
                rd_db <= 1'b0;
                end
            else
            begin
                rd_db <= 1'b1; // set rd_db high only on the first press
                first_press_rd <= 1'b0; // 
                rd_counter <= 23'd0;
            end
        end
        else
        begin
            first_press_rd <= 1'b1; // reset first_press when pb2 is released
            rd_db <= 1'b0;
            rd_counter <= 23'd0;
        end
    end
end


   



//write debounce
always_ff @(posedge CLK100)
begin
    if (reset)
    begin
        wr_counter <= 0;
        wr_db <= 0;
    end
    else
    begin 
        if (pb3_qq == 1'b1) // only debounce when pb3 is pressed
        begin
            if (wr_counter < 23'd5_000_000 && first_press ) // 0.05 sec at 100 MHz
//                 wr_counter <= wr_counter + 23'd1;
                begin
                wr_counter <= wr_counter + 23'd1;
                wr_db <= 1'b0;
                end
            else
            begin
                wr_db <= 1'b1; // set wr_db high only on the first press
                first_press <= 1'b0; // 
                wr_counter <= 23'd0;
            end
        end
        else
        begin
            first_press <= 1'b1; // reset first_press when pb3 is released
            wr_db <= 1'b0;
            wr_counter <= 23'd0;
        end
    end
end

/*// READ debounce
always_ff @(posedge CLK100) begin
    if (reset) begin
        rd_counter <= 23'd0;
        rd_db      <= 1'b0;
    end else begin
        if (pb2_qq == 1'b1) begin
            // button pressed: accept immediately
            rd_db      <= 1'b1;
            rd_counter <= 23'd0;   // stop release timer
        end else begin
            // button released: require 50 ms low to clear
            if (rd_counter < 23'd5_000_000)
                rd_counter <= rd_counter + 23'd1;
            else begin
                rd_db      <= 1'b0;
                rd_counter <= 23'd0;
            end
        end
    end
end */

/*// WRITE debounce: press -> immediate 1, release -> 50 ms low before clearing
always_ff @(posedge CLK100) begin
    if (reset) begin
        wr_counter <= 23'd0;
        wr_db      <= 1'b0;
    end else begin
        if (pb3_qq == 1'b1) begin
            wr_db      <= 1'b1;
            wr_counter <= 23'd0;
        end else begin
            if (wr_counter < 23'd5_000_000)
                wr_counter <= wr_counter + 23'd1;
            else begin
                wr_db      <= 1'b0;
                wr_counter <= 23'd0;
            end
        end
    end
end  */


//edge detect
always_ff @(posedge CLK100)
begin
    if (reset)
    begin
        rd_last <= 1'b0;
        wr_last <= 1'b0;
    end
else
    begin
    rd_last <= rd_db;
    wr_last <= wr_db;
    end
end



// // //Mode

// always_comb
// begin
  
//     if (mode_qqq == 1'b0) // write mode
//        LED[7:0] = rd_data;
//     else // read mode
//     begin
//         LED [7:4] = wr_index;
//         LED [3:0] = rd_index;
//     end
// end

//instantiate fifo
fifo15x8 fifo_inst
(
    .clk(CLK100),
    .reset(reset),
    .wr_request(wr_pulse /*& ~reset*/),
    .wr_data(data_in),
    .wr_index(wr_index),

    .rd_request(rd_pulse /*& ~reset*/),
    .rd_data(rd_data),
    .rd_index(rd_index),

    .empty(empty),
    .full(full),

    .clear_overflow_request(clear),
    .overflow(overflow)
);



// // --- PB1 / overflow debug (focused) ---
// assign LED[9] = mode_qqq;   // keep MODE visible
// assign LED[8] = overflow;   // overflow flag
// assign LED[7] = pb1_qq;     // PB1 post-sync level
// assign LED[6:0] = 7'b0;     // blank others for clarity



endmodule
