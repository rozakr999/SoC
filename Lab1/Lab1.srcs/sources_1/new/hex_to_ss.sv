`timescale 1ns / 1ps
////////////////////////////////////////////////////////////
// Company: University of Texas at Arlington
// Engineer: Rezwana Karim Roza
// ID: 1001919948
// 
// Create Date: 09/05/2025 09:16:10 PM
// Module Name: nibblecounter_top
// Project Name: Nibble Counter
// Target Devices:  xc7z007sclg400-1 (BlackBoard)
// Tool Versions: Xilinx Vivado 2022.2
///////////////////////////////////////////////////////




module hex_to_ss
 (
    input  logic [3:0] binary,   // hex digit 0–F
    output logic [7:0] sev  // {dp,g,f,e,d,c,b,a}, active-low
);

    always_comb begin
        case (binary)
            4'h0: sev = 8'b11000000; // 0
            4'h1: sev = 8'b11111001; // 1
            4'h2: sev = 8'b10100100; // 2
            4'h3: sev = 8'b10110000; // 3
            4'h4: sev = 8'b10011001; // 4
            4'h5: sev = 8'b10010010; // 5
            4'h6: sev = 8'b10000010; // 6
            4'h7: sev = 8'b11111000; // 7
            4'h8: sev = 8'b10000000; // 8
            4'h9: sev = 8'b10010000; // 9
            4'hA: sev = 8'b10001000; // A
            4'hB: sev = 8'b10000011; // b
            4'hC: sev = 8'b11000110; // C
            4'hD: sev = 8'b10100001; // d
            4'hE: sev = 8'b10000110; // E
            4'hF: sev = 8'b10001110; // F
            default: sev = 8'b11111111; // blank (all OFF)
        endcase
    end

endmodule


  
