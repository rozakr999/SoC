
`timescale 1 ns / 1 ps

    module i2c_slave_lite_v1_0_AXI_Interface #
    (
        // Bit width of S_AXI address bus
        parameter integer C_S_AXI_ADDR_WIDTH = 5
    )
    (
        // AXI clock and reset        
        input wire S_AXI_ACLK,
        input wire S_AXI_ARESETN,

        // AXI write channel
        // address:  add, protection, valid, ready
        // data:     data, byte enable strobes, valid, ready
        // response: response, valid, ready 
        input wire [C_S_AXI_ADDR_WIDTH-1:0] S_AXI_AWADDR,
        input wire [2:0] S_AXI_AWPROT,
        input wire S_AXI_AWVALID,
        output wire S_AXI_AWREADY,
        
        input wire [31:0] S_AXI_WDATA,
        input wire [3:0] S_AXI_WSTRB,
        input wire S_AXI_WVALID,
        output wire  S_AXI_WREADY,
        
        output wire [1:0] S_AXI_BRESP,
        output wire S_AXI_BVALID,
        input wire S_AXI_BREADY,
        
        // AXI read channel
        // address: add, protection, valid, ready
        // data:    data, resp, valid, ready
        input wire [C_S_AXI_ADDR_WIDTH-1:0] S_AXI_ARADDR,
        input wire [2:0] S_AXI_ARPROT,
        input wire S_AXI_ARVALID,
        output wire S_AXI_ARREADY,
        
        output wire [31:0] S_AXI_RDATA,
        output wire [1:0] S_AXI_RRESP,
        output wire S_AXI_RVALID,
        input wire S_AXI_RREADY,

        output wire i2c_clk,
        output wire scl_out,
        output wire sda_out,
        input wire sda_in,
        output wire [7:0] debug
    );

    // Internal registers
    reg [31:0] latch_addr;
    reg [31:0] latch_register;
    reg [31:0] latch_data;
    reg [31:0] latch_status;
    reg [31:0] latch_control;

    wire [31:0] read_addr;
    wire [31:0] read_register;
    wire [31:0] read_data;
    wire [31:0] read_status;
    wire [31:0] read_control;

    // Register map
    // ofs   fn
    //   0   address  (r/w)
    //   4   register (r/w)
    //   8   data     (r/w)
    //   12  status   (r/w1c)
    //   16  status   (r/w1c)
    
    // Register numbers
    localparam integer ADDR_REG             = 3'b000;
    localparam integer REGISTER_REG         = 3'b001;
    localparam integer DATA_REG             = 3'b010;
    localparam integer STATUS_REG           = 3'b011;
    localparam integer CONTROL_REG          = 3'b100;

    // status signals
    logic [23:0] debug_in;
    logic [7:0] debug_out;
    logic [3:0] fsm_state;

    // control signals
    logic ctl_rd;
    logic [3:0] ctl_cnt;
    logic ctl_usereg;
    logic ctl_rstart;
    logic ctl_start;
    logic ctl_tout;
    logic [7:0] ctl_debug;

    // AXI4-lite signals
    reg axi_awready;
    reg axi_wready;
    reg [1:0] axi_bresp;
    reg axi_bvalid;
    reg axi_arready;
    reg [31:0] axi_rdata;
    reg [1:0] axi_rresp;
    reg axi_rvalid;
    
    // friendly clock, reset, and bus signals from master
    wire axi_clk           = S_AXI_ACLK;
    wire axi_resetn        = S_AXI_ARESETN;
    wire [31:0] axi_awaddr = S_AXI_AWADDR;
    wire axi_awvalid       = S_AXI_AWVALID;
    wire axi_wvalid        = S_AXI_WVALID;
    wire [3:0] axi_wstrb   = S_AXI_WSTRB;
    wire axi_bready        = S_AXI_BREADY;
    wire [31:0] axi_araddr = S_AXI_ARADDR;
    wire axi_arvalid       = S_AXI_ARVALID;
    wire axi_rready        = S_AXI_RREADY; 

	//Fifo signals
	wire clear_overflow_request;

    // assign bus signals to master to internal reg names
    assign S_AXI_AWREADY = axi_awready;
    assign S_AXI_WREADY  = axi_wready;
    assign S_AXI_BRESP   = axi_bresp;
    assign S_AXI_BVALID  = axi_bvalid;
    assign S_AXI_ARREADY = axi_arready;
    assign S_AXI_RDATA   = axi_rdata;
    assign S_AXI_RRESP   = axi_rresp;
    assign S_AXI_RVALID  = axi_rvalid;
    
  

    // Assert address ready handshake (axi_awready) 
    // - after address is valid (axi_awvalid)
    // - after data is valid (axi_wvalid)
    // - while configured to receive a write (aw_en)
    // De-assert ready (axi_awready)
    // - after write response channel ready handshake received (axi_bready)
    // - after this module sends write response channel valid (axi_bvalid) 
    wire wr_add_data_valid = axi_awvalid && axi_wvalid;
    reg aw_en;
    always_ff @ (posedge axi_clk)
    begin
        if (axi_resetn == 1'b0)
        begin
            axi_awready <= 1'b0;
            aw_en <= 1'b1;
        end
        else
        begin
            if (wr_add_data_valid && ~axi_awready && aw_en)
            begin
                axi_awready <= 1'b1;
                aw_en <= 1'b0;
            end
            else if (axi_bready && axi_bvalid)
                begin
                    aw_en <= 1'b1;
                    axi_awready <= 1'b0;
                end
            else           
                axi_awready <= 1'b0;
        end 
    end

    // Capture the write address (axi_awaddr) in the first clock (~axi_awready)
    // - after write address is valid (axi_awvalid)
    // - after write data is valid (axi_wvalid)
    // - while configured to receive a write (aw_en)
    reg [C_S_AXI_ADDR_WIDTH-1:0] waddr;
    always_ff @ (posedge axi_clk)
    begin
        if (axi_resetn == 1'b0)
            waddr <= 0;
        else if (wr_add_data_valid && ~axi_awready && aw_en)
            waddr <= axi_awaddr;
    end

    // Output write data ready handshake (axi_wready) generation for one clock
    // - after address is valid (axi_awvalid)
    // - after data is valid (axi_wvalid)
    // - while configured to receive a write (aw_en)
    always_ff @ (posedge axi_clk)
    begin
        if (axi_resetn == 1'b0)
            axi_wready <= 1'b0;
        else
            axi_wready <= (wr_add_data_valid && ~axi_wready && aw_en);
    end       

    // Write data to internal registers
    // - after address is valid (axi_awvalid)
    // - after write data is valid (axi_wvalid)
    // - after this module asserts ready for address handshake (axi_awready)
    // - after this module asserts ready for data handshake (axi_wready)
    // write correct bytes in 32-bit word based on byte enables (axi_wstrb)
    // int_clear_request write is only active for one clock
    wire wr = wr_add_data_valid && axi_awready && axi_wready;
    integer byte_index;
    always_ff @ (posedge axi_clk)
    begin
        if (axi_resetn == 1'b0)
        begin
            latch_addr[31:0] <= 32'b0;
            latch_register[31:0] <= 32'b0;
            latch_data[31:0] <= 32'b0;
            latch_status[31:0] <= 32'b0;
            latch_control[31:0] <= 32'b0;
        end 
        else 
        begin
            if (wr)
            begin
                case (axi_awaddr[4:2])
                    ADDR_REG:
                        for (byte_index = 0; byte_index <= 3; byte_index = byte_index+1)
                            if ( axi_wstrb[byte_index] == 1) 
                                latch_addr[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
                    REGISTER_REG:
                        for (byte_index = 0; byte_index <= 3; byte_index = byte_index+1)
                            if ( axi_wstrb[byte_index] == 1) 
                                latch_register[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
                    DATA_REG:
                        for (byte_index = 0; byte_index <= 3; byte_index = byte_index+1)
                            if ( axi_wstrb[byte_index] == 1) 
                                latch_data[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
                    STATUS_REG:
                        for (byte_index = 0; byte_index <= 3; byte_index = byte_index+1)
                            if (axi_wstrb[byte_index] == 1)
                                latch_status[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
                    CONTROL_REG:
                         for (byte_index = 0; byte_index <= 3; byte_index = byte_index+1)
                            if (axi_wstrb[byte_index] == 1)
                                latch_control[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
                    default:
                    begin
                        latch_addr <= latch_addr;
                        latch_register <= latch_register;
                        latch_data <= latch_data;
                        latch_status <= 32'd0;
                        latch_control <= latch_control;
                    end
                endcase
            end
            else
            begin
                latch_addr <= latch_addr;
                latch_register <= latch_register;
                latch_data <= latch_data;
                latch_status <= 32'd0;
                latch_control <= latch_control;
            end
        end
    end    

    // Send write response (axi_bvalid, axi_bresp)
    // - after address is valid (axi_awvalid)
    // - after write data is valid (axi_wvalid)
    // - after this module asserts ready for address handshake (axi_awready)
    // - after this module asserts ready for data handshake (axi_wready)
    // Clear write response valid (axi_bvalid) after one clock
    wire wr_add_data_ready = axi_awready && axi_wready;
    always_ff @ (posedge axi_clk)
    begin
        if (axi_resetn == 1'b0)
        begin
            axi_bvalid  <= 0;
            axi_bresp   <= 2'b0;
        end 
        else
        begin    
            if (wr_add_data_valid && wr_add_data_ready && ~axi_bvalid)
            begin
                axi_bvalid <= 1'b1;
                axi_bresp  <= 2'b0;
            end
            else if (S_AXI_BREADY && axi_bvalid) 
                axi_bvalid <= 1'b0; 
        end
    end   

    // In the first clock (~axi_arready) that the read address is valid
    // - capture the address (axi_araddr)
    // - output ready (axi_arready) for one clock
    reg [C_S_AXI_ADDR_WIDTH-1:0] raddr;
    always_ff @ (posedge axi_clk)
    begin
        if (axi_resetn == 1'b0)
        begin
            axi_arready <= 1'b0;
            raddr <= 32'b0;
        end 
        else
        begin    
            // if valid, pulse ready (axi_rready) for one clock and save address
            if (axi_arvalid && ~axi_arready)
            begin
                axi_arready <= 1'b1;
                raddr  <= axi_araddr;
            end
            else
                axi_arready <= 1'b0;
        end 
    end       
        
    // Update register read data
    // - after this module receives a valid address (axi_arvalid)
    // - after this module asserts ready for address handshake (axi_arready)
    // - before the module asserts the data is valid (~axi_rvalid)
    //   (don't change the data while asserting read data is valid)
    wire rd = axi_arvalid && axi_arready && ~axi_rvalid;
    always_ff @ (posedge axi_clk)
    begin
        if (axi_resetn == 1'b0)
        begin
            axi_rdata <= 32'b0;
        end 
        else
        begin    
            if (rd)
            begin
		// Address decoding for reading registers
                case (raddr[4:2])
                    ADDR_REG: 
                        axi_rdata <= read_addr;
                    REGISTER_REG: 
                        axi_rdata <= read_register;
                    DATA_REG: 
                        axi_rdata <= read_data;
                    STATUS_REG: 
                        axi_rdata <= read_status;
                    CONTROL_REG:
                        axi_rdata <= read_control;
                    default:
                        axi_rdata <= 32'b0;
                endcase
            end
            else
                axi_rdata <= 32'b0;
        end
    end    

    // Assert data is valid for reading (axi_rvalid)
    // - after address is valid (axi_arvalid)
    // - after this module asserts ready for address handshake (axi_arready)
    // De-assert data valid (axi_rvalid) 
    // - after master ready handshake is received (axi_rready)
    always_ff @ (posedge axi_clk)
    begin
        if (axi_resetn == 1'b0)
            axi_rvalid <= 1'b0;
        else
        begin
            if (axi_arvalid && axi_arready && ~axi_rvalid)
            begin
                axi_rvalid <= 1'b1;
                axi_rresp <= 2'b0;
            end   
            else if (axi_rvalid && axi_rready)
                axi_rvalid <= 1'b0;
        end
    end

logic tx_wr_request;
logic tx_rd_request;
logic tx_empty;
logic tx_full;
logic tx_overflow;
logic [7:0] tx_wr_data;
logic [7:0] tx_rd_data;

logic rx_wr_request;
logic rx_rd_request;
logic rx_empty;
logic rx_full;
logic rx_overflow;
logic [7:0] rx_wr_data;
logic [7:0] rx_rd_data;
logic [3:0] tx_wr_index;
logic [3:0] tx_rd_index;
logic [3:0] tx_cnt;
logic [3:0] rx_wr_index;
logic [3:0] rx_rd_index;
logic [3:0] rx_cnt;

logic pulse_400khz;
logic pulse_200khz;
logic c_start;
logic s_ack;
logic s_busy;
logic fifo_rx_clear_req;
logic fifo_tx_clear_req;
logic ack_clear_req;
logic manual_reset;

always_ff @(posedge axi_clk)
begin
    tx_wr_request <= wr && (axi_awaddr[4:2] == DATA_REG);
    rx_rd_request <= rd && (axi_araddr[4:2] == DATA_REG);
    c_start <= wr && (axi_awaddr[4:2] == CONTROL_REG) && axi_wstrb[0] && S_AXI_WDATA[7];
end

assign read_addr      = {{25{1'b0}}, latch_addr[6:0]};
assign read_register  = {{24{1'b0}}, latch_register[7:0]};
assign read_data      = {{24{1'b0}}, rx_rd_data[7:0]};

assign read_status[0]    = rx_overflow;   // RX FIFO overflow (write 1 to clear)
assign read_status[1]    = rx_full;       // RX FIFO full (auto clears when data is read)
assign read_status[2]    = rx_empty;      // RX FIFO empty (auto clears when data arrives)
assign read_status[3]    = tx_overflow;   // TX FIFO overflow (write 1 to clear)
assign read_status[4]    = tx_full;       // TX FIFO full (auto clears when data is sent)
assign read_status[5]    = tx_empty;      // TX FIFO empty (auto clears when data is written)
assign read_status[6]    = s_ack;         // An ACK error occurred (write 1 to clear)
assign read_status[7]    = s_busy;        // The module is busy transmitting or receiving (write 1 to reset)
assign read_status[31:8] = debug_in;      // Debug interface (often used to peek at FSM)

assign read_control[0]     = latch_control[0]; // R/~W (Direction of data on bus, read=1, write=0)
assign read_control[4:1]   = latch_control[4:1]; // BYTE_COUNT
assign read_control[5]     = latch_control[5]; // USE_REGISTER (Use the register address for this transaction)
assign read_control[6]     = latch_control[6]; // REPEAT START (Generate a repeat start condition)
assign read_control[7]     = 1'b0;             // START (Generate a transaction, always read as 0)
assign read_control[8]     = latch_control[8]; // TEST_OUT (Generate 200kHz test clock signal)
assign read_control[23:9]  = 15'b0;                // Reserved
assign read_control[31:24] = latch_control[31:24]; // Debug interface

assign ctl_rd         = latch_control[0]; // R/~W (Direction of data on bus, read=1, write=0)
assign ctl_cnt        = latch_control[4:1]; // BYTE_COUNT (Number of bytes to be written or read)
assign ctl_usereg     = latch_control[5]; // USE_REGISTER (Use the register address for this transaction)
assign ctl_rstart     = latch_control[6]; // REPEAT START (Generate a repeat start condition)
assign ctl_start      = c_start; // START (Generate a transaction)
assign ctl_tout       = latch_control[8]; // TEST_OUT (Generate 200kHz test clock signal)
assign ctl_debug      = latch_control[31:24]; // Debug interface

assign debug_in[3:0]   = fsm_state[3:0];
assign debug_in[6]     = pulse_400khz;
assign debug_in[7]     = ctl_start;
assign debug_in[11:8]  = tx_cnt[3:0];
assign debug_in[15:12] = rx_cnt[3:0];
assign debug_in[23:16]  = {8{1'b0}};

assign debug = debug_out;

// Choose one of the two options:
assign debug_out = debug_in[7:0]; // (for hardware debug ILA)
// assign debug_out = ctl_debug; // (for software debug ILA)

assign i2c_clk = pulse_200khz & ctl_tout;
assign tx_wr_data = latch_data[7:0];

assign fifo_rx_clear_req = latch_status[0];
assign fifo_tx_clear_req = latch_status[3];
assign ack_clear_req = latch_status[6];
assign manual_reset = latch_status[7];

assign tx_cnt = tx_wr_index - tx_rd_index;
assign rx_cnt = rx_wr_index - rx_rd_index;

i2c_clock i2c_clock_inst
(
    .clk_100mhz(axi_clk),
    .pulse_400khz(pulse_400khz),
    .pulse_200khz(pulse_200khz)
);

fifo15x8 fifo_i2c_tx
(
    .clk(axi_clk),
    .reset(~axi_resetn | manual_reset),

    .wr_request(tx_wr_request),
    .wr_data(tx_wr_data),
    .wr_index(tx_wr_index),

    .rd_request(tx_rd_request),
    .rd_data(tx_rd_data),
    .rd_index(tx_rd_index),

    .empty(tx_empty),
    .full(tx_full),

    .clear_overflow_request(fifo_tx_clear_req),
    .overflow(tx_overflow)
);

fifo15x8 fifo_i2c_rx
(
    .clk(axi_clk),
    .reset(~axi_resetn | manual_reset),

    .wr_request(rx_wr_request),
    .wr_data(rx_wr_data),
    .wr_index(rx_wr_index),

    .rd_request(rx_rd_request),
    .rd_data(rx_rd_data),
    .rd_index(rx_rd_index),

    .empty(rx_empty),
    .full(rx_full),

    .clear_overflow_request(fifo_rx_clear_req),
    .overflow(rx_overflow)
);

// fsm
i2c_fsm i2c_fsm_inst
(
    .clk(axi_clk),
    .ena(pulse_400khz),
    .sync(pulse_200khz),
    .resetn(axi_resetn & ~manual_reset),

    // data signals
    .d_addr(latch_addr[6:0]),
    .d_reg(latch_register[7:0]),
    .d_data(tx_rd_data),

    // status signals
    .s_ack(s_ack),
    .s_busy(s_busy),
    
    // control signals
    .c_wr(~ctl_rd),
    .c_cnt(ctl_cnt),
    .c_usereg(ctl_usereg),
    .c_rstart(ctl_rstart),
    .c_start(ctl_start),
    
    .ack_clear_req(ack_clear_req),
    .fifo_read_req(tx_rd_request),
    .fifo_write_req(rx_wr_request),

    .data_out(rx_wr_data),
    .state_out(fsm_state),

    .scl_out(scl_out),
    .sda_out(sda_out),
    .sda_in(sda_in)
);

endmodule
