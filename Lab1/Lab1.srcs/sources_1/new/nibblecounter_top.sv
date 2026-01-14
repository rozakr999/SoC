`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: University of Texas at Arlington
// Engineer: Rezwana Karim Roza
// ID: 1001919948
// 
// Create Date: 09/05/2025 09:16:10 PM
// Module Name: nibblecounter_top
// Project Name: Nibble Counter
// Target Devices:  xc7z007sclg400-1 (BlackBoard)
// Tool Versions: Xilinx Vivado 2022.2
//////////////////////////////////////////////////////////////////////////////////

//top module
module nibblecounter_top
(
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
    
   
// assign LED = 10'b0000000000;
assign RGB0 = 3'b000;
assign RGB1 = 3'b000;
//assign SS_ANODE = 4'b0000;
//assign SS_CATHODE = 8'b11111111;
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




logic [7:0] d0, d1, d2, d3; // cathode patterns for each digit
logic [15:0] count;      // 16-bit counter
logic [3:0][7:0] display_data; // 4 digits of 7-segment display data
logic [24:0] divider_counter = 25'd0; // clock divider counter
logic tick_250ms = 1'b0;          // tick at 250 ms
logic pb_q, pb_qq, pb_qqq; // pushbutton synchronization
logic sw11_q, sw11_qq; // switch 11 synchronization
logic [10:0] sw_q, sw_qq; // switches 10 to 0 synchronization
logic [15:0] delta;
logic pb1_q, pb1_qq, pb1_qqq; // pushbutton 1 synchronization
logic pb2_q, pb2_qq, pb2_qqq; // pushbutton 2 synchronization
logic [15:0] minimum; 

initial begin
    minimum = 16'h0000;
end
logic [15:0] maximum = 16'hFFFF;

// step 9
logic pb3_q, pb3_qq, pb3_qqq; // pushbutton 3 synchronization
logic [15:0] match = 16'h0000; // match value for pushbutton 3
logic led0_tgl;  // drives LED[0]
logic preset; 
logic preset_stable;


wire pb_press;
wire sw11_up ;
wire pb1_press;
wire pb2_press;
wire pb3_press;


assign pb1_press = (~pb1_qqq) & pb1_qq;   
assign pb2_press = (~pb2_qqq) & pb2_qq;   
assign pb3_press = (~pb3_qqq) & pb3_qq;   
assign pb_press = pb_qq;
assign sw11_up = sw11_qq;
assign delta = {5'b00000, sw_qq} ; // zero extend to 16 bits

assign display_data [0] = d0;
assign display_data [1] = d1; 
assign display_data [2] = d2;
assign display_data [3] = d3;
assign LED = {9'b0, led0_tgl}; // drive LED0 with led0_tgl


// pushbutton synchronization and edge detection
always_ff @(posedge CLK100) begin
    {pb_qqq, pb_qq, pb_q} <= {pb_qq, pb_q, PB[0]};
end

//switch 11 synchronization
always_ff @(posedge CLK100) begin
    {sw11_qq, sw11_q} <= {sw11_q, SW[11]};
end

//switches 10 to 0 synchronization
always_ff @(posedge CLK100) begin
    {sw_qq, sw_q} <= {sw_q, SW[10:0]};
end

///////////step 8///////////////
// pushbutton 1 synchronization and edge detection
always_ff @(posedge CLK100) begin
    {pb1_qqq, pb1_qq, pb1_q} <= {pb1_qq, pb1_q, PB[1]};
end

// pushbutton 2 synchronization and edge detection
always_ff @(posedge CLK100) begin
    {pb2_qqq, pb2_qq, pb2_q} <= {pb2_qq, pb2_q, PB[2]};
end

///////////step 9///////////////
// pushbutton 3 synchronization and edge detection
always_ff @(posedge CLK100) begin
    {pb3_qqq, pb3_qq, pb3_q} <= {pb3_qq, pb3_q, PB[3]};
end


// clock divider to generate tick_250ms
always_ff @(posedge CLK100) begin
    if (divider_counter == 25'd24_999_999) begin // 100MHz/4Hz = 25,000,000//25'd24_999_999
        divider_counter <= 25'd0;
        tick_250ms <= 1'b1;
    end
    else begin
        divider_counter <= divider_counter + 1'b1;
        tick_250ms <= 1'b0;
    end
end


// preset logic
always_ff @(posedge CLK100) begin

    if (pb_press) begin
      preset_stable <= 1'b0; // user pressed PB0 → not preset anymore
     preset <= 1'b0;   // user pressed PB0 → not preset anymore

    end else begin
      preset_stable <= 1'b1; // only POR triggered → preset defaults
      preset <= ~preset_stable;   // only POR triggered → preset defaults
    end
  
end

// max min logic
always_ff @(posedge CLK100) begin
  if (pb_press| preset) begin 
    minimum <= 16'h0000;
    maximum <= 16'hFFFF;
  end else begin
    // if (pb1_press) minimum <= count;   // set MIN to current count (one time)
    // if (pb2_press) maximum <= count;   // set MAX to current count (one time)
    if (pb1_press && (count <= maximum)) minimum <= count;
   if (pb2_press && (count >= minimum)) maximum <= count;
    if (minimum > maximum)
      {minimum, maximum} <= {maximum, minimum};
  end
end


//////////////step 9 //////////////////
// match value logic
always_ff @(posedge CLK100) begin
  if (pb_press) begin
    match <= 16'h0000; // reset match value on button press
  end else if (pb3_press) begin
    match <= count; // set match value to current count on button press
  end
end

// main counting logic with range wrap
logic [16:0] range17;
logic [16:0] work_value;
logic busy;

always_ff @(posedge CLK100) begin
  if (pb_press) begin
    count      <= 16'h0000;
    busy       <= 1'b0;
    work_value <= 17'd0;
    led0_tgl   <= 1'b0;        // reset LED state with PB0
  end else begin
    range17 <= {1'b0, maximum} - {1'b0, minimum} + 17'd1;

    // Start an update on tick_250ms
    if (tick_250ms && !busy) begin
      busy <= 1'b1;
      if (sw11_up)
        work_value <= {1'b0, count} + {1'b0, delta};
      else
        work_value <= {1'b0, count} - {1'b0, delta};
    end

    else if (busy) begin
      if (work_value > {1'b0, maximum})
        work_value <= work_value - range17;
      else if (work_value < {1'b0, minimum})
        work_value <= work_value + range17;
      else begin
    
        count <= work_value[15:0];

    if (work_value[15:0] == match)
      led0_tgl <= ~led0_tgl;

        busy  <= 1'b0;
      end
    end
  end
end



// hex to 7-segment decoder instances
hex_to_ss hex0 (.binary(count[3:0]), .sev(d0));
hex_to_ss hex1 (.binary(count[7:4]), .sev(d1));             
hex_to_ss hex2 (.binary(count[11:8]), .sev(d2));
hex_to_ss hex3 (.binary(count[15:12]), .sev(d3));

// seven segment display instance
seven_seg ss0 (.clk(CLK100), .data(display_data), .anode(SS_ANODE), .cathode(SS_CATHODE));


    
endmodule
