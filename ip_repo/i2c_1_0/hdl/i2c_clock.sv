module i2c_clock
(
    input clk_100mhz,
    output logic pulse_400khz,
    output logic pulse_200khz
);

    // 100 MHz to 200 kHz clock divider
    // 100 MHz / 200 kHz = 500
    // toggle every 250 cycles

logic [31:0] counter;
logic [31:0] counter2;

always_ff @(posedge clk_100mhz) begin
    counter <= (counter == 32'd249) ? 32'd0 : (counter + 32'd1);
end

always_ff @(posedge clk_100mhz) begin
    counter2 <= (counter2 == 32'd499) ? 32'd0 : (counter2 + 32'd1);
end

   
    // 100 MHz to 400 kHz clock divider
    // 100 MHz / 400 kHz = 250
    // pulse every 250 cycles

assign pulse_400khz = (counter == 32'd249);
assign pulse_200khz = (counter2 == 32'd499);

endmodule
