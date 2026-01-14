`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 10/04/2025 03:26:54 AM
// Design Name: 
// Module Name: fifo15x8
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


module fifo15x8
(
    input logic clk,
    input logic reset,

    input logic wr_request,
    input logic [7:0] wr_data,
    output logic [3:0] wr_index,


    input logic rd_request,
    output logic [7:0] rd_data,
    output logic [3:0] rd_index,


    output logic empty,
    output logic full,

    input logic clear_overflow_request,
    output logic overflow

 );

logic [7:0] fifo_mem [0:15];

//flags
assign empty = (wr_index == rd_index);
assign full = ((wr_index + 4'd1)  == rd_index);

assign rd_data = fifo_mem[rd_index];


//write counter
always_ff @(posedge clk)
begin
    if (reset)
    begin
        wr_index <= 4'b0;
        fifo_mem <= '{default:'0};
    end
    else if (wr_request && !full)
    begin
        fifo_mem[wr_index] <= wr_data;
        wr_index <= wr_index + 4'd1;
    end
    //else
        //wr_index <= wr_index;   
end


//read counter
always_ff @(posedge clk)
begin
    if (reset) 
    begin
        rd_index <= 4'b0;
        //rd_data <= 8'b0;
    end
    else if (rd_request && !empty)
    begin
        //rd_data <= fifo_mem[rd_index];
        rd_index <= rd_index + 4'd1;
    end
    //else
        //rd_index <= rd_index;
end

//overflow flag
always_ff @(posedge clk)
begin
    if (reset || clear_overflow_request)
    begin
        overflow <= 1'b0;
    end
    else if (wr_request && full)
    begin
        overflow <= 1'b1;
    end
    
end



endmodule
