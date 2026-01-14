module fsm
(
    input clk,
    input ena,
    input resetn,

    // data signals
    input [6:0] d_addr,
    input [7:0] d_reg,
    input [7:0] d_data,

    // control signals
	input c_wr,
    input [3:0] c_cnt,
    input c_usereg,
    input c_rstart,
    input c_start,

    output logic fifo_read_req,
    output logic fifo_write_req,

    output logic [7:0] data_out,
    output logic [3:0] state_out,
    output logic [5:0] cnt_out,

    output logic scl_out,
    output logic sda_out, 
    input sda_in
);


// types of actions:
// - write simple 
// - write complex
// - read simple
// - read complex

parameter  IDLE = 4'd0;
parameter  START = 4'd1;
parameter  STOP = 4'd2;
parameter  RD_STOP = 4'd3;
parameter  RD_START = 4'd4;
parameter  TX_ADDR = 4'd5;
parameter  TX_REG = 4'd6;
parameter  TX_DATA = 4'd7;
parameter  RD_TX_ADDR = 4'd8;
parameter  RD_RX_DATA = 4'd9;

logic start_sync;
logic start_request;

logic [1:0] start_cnt;
logic [1:0] stop_cnt;

logic [5:0] bit_cnt;
logic [5:0] bit_cntr;
logic [3:0] byte_cnt;
logic [3:0] byte_cntr;
logic ena_q;
logic ena_pulse;
logic next_byte;
logic next_byte_early;
logic ack;

logic [9:0] tx_addr_val;
logic [9:0] tx_reg_val;
logic [9:0] tx_data_val;
logic [9:0] rd_addr_val;

logic [3:0] state;
logic [3:0] next_state;

assign tx_addr_val = {d_addr, 1'b0, 1'b1};
assign tx_reg_val = {d_reg, 1'b1};
assign tx_data_val = {d_data, 1'b1};
assign rd_addr_val = {d_addr, 1'b1, 1'b1};
assign state_out = state;
assign ena_pulse = ena && !ena_q;
assign start_request = (start_sync | c_start) & ena;
assign cnt_out = bit_cntr;

always_ff @(posedge clk)
    if (!resetn | ena)
        start_sync <= 1'b0;
    else
        start_sync <= c_start | start_sync;

always_ff @(posedge clk)
    if (!resetn && (state < TX_ADDR))
        bit_cntr <= 6'd35;
    else if (ena && (state >= TX_ADDR))
        bit_cntr <= bit_cnt;
    else
        bit_cntr <= bit_cntr;

always_ff @(posedge clk)
    if (!resetn)
        ack <= 1'b1;
    else if (ena && bit_cntr == 6'd2)
        ack <= ~sda_in;
    else
        ack <= ack;

always_ff @(posedge clk)
    if (state == START && ena)
        byte_cntr <= c_cnt;
	 else
        byte_cntr <= byte_cnt;

always_ff @(posedge clk)
    if (!resetn)
        data_out <= 8'd0;
    else if ((state == RD_RX_DATA) && (bit_cntr > 6'd3) && (bit_cntr[1:0] == 2'b00) && ena)
        data_out[bit_cntr[5:2] - 3'd1] <= sda_in;
    else
        data_out <= data_out;

always_ff @(posedge clk)
    ena_q <= ena;

always_ff @(posedge clk)
begin
    fifo_read_req <= (state == TX_DATA) && next_byte_early && ena_pulse && byte_cntr;
    fifo_write_req <= (state == RD_RX_DATA) && next_byte_early && ena_pulse && byte_cntr;
end

always_ff @(posedge clk)
    if (!resetn)
        start_cnt <= 2'd2 + c_rstart;

    else if ((state == START || state == RD_START) && ena)
        start_cnt <= (start_cnt) ?  start_cnt - 2'd1 : 2'd2 + c_rstart;
    
    else
        start_cnt <= start_cnt;

always_ff @(posedge clk)
    if (!resetn)
        stop_cnt <= 2'd2;

    else if ((state == STOP || state == RD_STOP) && ena)
        stop_cnt <= (stop_cnt) ?  stop_cnt - 2'd1 : 2'd2;

    else
        stop_cnt <= stop_cnt;
    

always_ff @(posedge clk)
    if (!resetn)
        state <= IDLE;
    else if (state == IDLE)
        state <= next_state;
    else if (ena)
        state <= next_state;
    else
		state <= state;

always_comb
begin
    scl_out = 1'b1;
	sda_out = 1'b1;
    next_state = state;

    case(state)
        IDLE:
        begin
            scl_out = 1'b1;
            sda_out = 1'b1;

            // write simple
            // write complex
            // read simple
            if (start_request)
                next_state = START;

            else
                next_state = IDLE;
        end

        START:
        begin
            scl_out = (start_cnt > 2'd0);
            sda_out = (start_cnt > 2'd1);
            
            if (!ena || start_cnt)
                next_state = START;

            // write simple
            // write complex
            // read complex
            else if (c_usereg || c_wr)
                next_state = TX_ADDR;

            // read simple
            else
                next_state = RD_TX_ADDR;
        end

        TX_ADDR:
        begin
            scl_out = ^bit_cntr[1:0];
            sda_out = tx_addr_val[bit_cntr[5:2]];

            if (!ack)
                next_state = IDLE;

            else if (!next_byte)
                next_state = TX_ADDR;

            // write simple
            else if (!c_usereg)
                next_state = TX_DATA;

            // write complex
            // read complex
            else if (c_usereg)
                next_state = TX_REG;
        end

        TX_REG:
        begin
            scl_out = ^bit_cntr[1:0];
            sda_out = tx_reg_val[bit_cntr[5:2]];

            if (!ack)
                next_state = IDLE;

            else if (!next_byte)
                next_state = TX_REG;

            // write complex
            else if (c_wr)
                next_state = TX_DATA;

            // read complex - no repeated start
            else if (!c_rstart)
                next_state = RD_STOP;

            // read complex - repeated start
            else if (c_rstart)
                next_state = RD_START;
        end

        TX_DATA:
        begin
            scl_out = ^bit_cntr[1:0];
            sda_out = tx_data_val[bit_cntr[5:2]];

            if (!ack)
                next_state = IDLE;

            else if (!byte_cnt)
                next_state = STOP;

            else
                next_state = TX_DATA;
        end

        RD_STOP:
        begin
            scl_out = (stop_cnt < 2'd2);
            sda_out = (stop_cnt < 2'd1);

            if (!ena || stop_cnt)
                next_state = RD_STOP;
            else
                next_state = RD_START;
        end

        RD_START:
        begin
            scl_out = ^start_cnt;
            sda_out = (start_cnt > 2'd1);
            if (!ena || start_cnt)
                next_state = RD_START;
            else
                next_state = RD_TX_ADDR;
        end

        RD_TX_ADDR:
        begin
            scl_out = ^bit_cntr[1:0];
            sda_out = rd_addr_val[bit_cntr[5:2]];
            
            if (!ack)
                next_state = IDLE;

            else if (next_byte)
                next_state = RD_RX_DATA;

            else
                next_state = RD_TX_ADDR;
        end

        RD_RX_DATA:
        begin
            scl_out = ^bit_cntr[1:0];
            if (!ack)
                next_state = IDLE;

            else if (!byte_cnt)
                next_state = STOP;

            else
                next_state = RD_RX_DATA;
        end

        STOP:
        begin
            scl_out = (stop_cnt < 2'd2);
            sda_out = (stop_cnt < 2'd1);

            if (!ena || stop_cnt)
                next_state = STOP;
            else
                next_state = IDLE;
        end

        default:
            next_state = IDLE;

    endcase
end

assign next_byte = bit_cntr == 6'd0 && ena;
assign next_byte_early = bit_cntr == 6'd4 && ena;
assign byte_cnt = ((state == TX_DATA || state == RD_RX_DATA) && next_byte && byte_cntr) ? byte_cntr - 4'd1 : byte_cntr;
assign bit_cnt = bit_cntr != 6'd0 ? (bit_cntr - 6'd1) : 6'd35;


endmodule
