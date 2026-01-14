`timescale 1ns / 1ps
//////////////////////////////////////////////////////
// Company: University of Texas at Arlington
// Engineer: Rezwana Karim Roza
// ID: 1001919948
// 
// Create Date: 09/05/2025 09:16:10 PM
// Module Name: nibblecounter_top
// Project Name: Nibble Counter
// Target Devices:  xc7z007sclg400-1 (BlackBoard)
// Tool Versions: Xilinx Vivado 2022.2
/////////////////////////////////////////////////////


module seven_seg 
(

    input logic clk,
    input logic [3:0][7:0] data,
    output logic [3:0] anode,       // Anodes 3..0 placed from left to right
    output logic [7:0] cathode      // Bit order: DP, G, F, E, D, C, B, A
);

// divide 100 MHz clock to about 1 kHz so total 4khz

logic [14:0] counter;  // 15 bits is enough to count to 32768
logic tick = 1'b0; 
logic [1:0] state = 2'b00; // state variable for 4 states

always_ff @(posedge clk) begin
    if (counter == 15'd24999) begin // 100MHz/25000 = 4kHz
        counter <= '0;
        tick <= 1'b1;
    end
    else begin
        counter <= counter + 1'b1;
        tick <= 1'b0;
    end
end
    

//state machine to cycle through the 4 digits
always_ff @(posedge clk) begin
    if (tick) begin
       case (state)
           2'b00: state <= 2'b01;
           2'b01: state <= 2'b10;
           2'b10: state <= 2'b11;
           2'b11: state <= 2'b00;
           default: state <= 2'b00;
       endcase
end
end

//set anode with active low
always_comb begin
    case (state)
        2'b00: anode = 4'b1110;
        2'b01: anode = 4'b1101;
        2'b10: anode = 4'b1011;
        2'b11: anode = 4'b0111;
        default: anode = 4'b1111;
    endcase
end

//set cathode with active low
always_comb begin   
    case (state)
        2'b00: cathode = data[0];
        2'b01: cathode = data[1];
        2'b10: cathode = data[2];
        2'b11: cathode = data[3];
        default: cathode = 8'b11111111;
    endcase
end

endmodule