
`timescale 1 ns / 1 ps

	module i2c #
	(
		// Users to add parameters here

		// User parameters ends
		// Do not modify the parameters beyond this line


		// Parameters of Axi Slave Bus Interface AXI_Interface
		parameter integer C_AXI_Interface_DATA_WIDTH	= 32,
		parameter integer C_AXI_Interface_ADDR_WIDTH	= 5
	)
	(
		// Users to add ports here

		// User ports ends
		// Do not modify the ports beyond this line


		// Ports of Axi Slave Bus Interface AXI_Interface
		input wire  axi_interface_aclk,
		input wire  axi_interface_aresetn,
		input wire [C_AXI_Interface_ADDR_WIDTH-1 : 0] axi_interface_awaddr,
		input wire [2 : 0] axi_interface_awprot,
		input wire  axi_interface_awvalid,
		output wire  axi_interface_awready,
		input wire [C_AXI_Interface_DATA_WIDTH-1 : 0] axi_interface_wdata,
		input wire [(C_AXI_Interface_DATA_WIDTH/8)-1 : 0] axi_interface_wstrb,
		input wire  axi_interface_wvalid,
		output wire  axi_interface_wready,
		output wire [1 : 0] axi_interface_bresp,
		output wire  axi_interface_bvalid,
		input wire  axi_interface_bready,
		input wire [C_AXI_Interface_ADDR_WIDTH-1 : 0] axi_interface_araddr,
		input wire [2 : 0] axi_interface_arprot,
		input wire  axi_interface_arvalid,
		output wire  axi_interface_arready,
		output wire [C_AXI_Interface_DATA_WIDTH-1 : 0] axi_interface_rdata,
		output wire [1 : 0] axi_interface_rresp,
		output wire  axi_interface_rvalid,
		input wire  axi_interface_rready,
		output wire i2c_clk,
		output wire scl_out,
		output wire sda_out,
		input wire sda_in,
		output wire [7:0] debug
	);
// Instantiation of Axi Bus Interface AXI_Interface
	i2c_slave_lite_v1_0_AXI_Interface # ( 
		//.C_S_AXI_DATA_WIDTH(C_AXI_Interface_DATA_WIDTH),
		.C_S_AXI_ADDR_WIDTH(C_AXI_Interface_ADDR_WIDTH)
	) i2c_slave_lite_v1_0_AXI_Interface_inst (
		.S_AXI_ACLK(axi_interface_aclk),
		.S_AXI_ARESETN(axi_interface_aresetn),
		.S_AXI_AWADDR(axi_interface_awaddr),
		.S_AXI_AWPROT(axi_interface_awprot),
		.S_AXI_AWVALID(axi_interface_awvalid),
		.S_AXI_AWREADY(axi_interface_awready),
		.S_AXI_WDATA(axi_interface_wdata),
		.S_AXI_WSTRB(axi_interface_wstrb),
		.S_AXI_WVALID(axi_interface_wvalid),
		.S_AXI_WREADY(axi_interface_wready),
		.S_AXI_BRESP(axi_interface_bresp),
		.S_AXI_BVALID(axi_interface_bvalid),
		.S_AXI_BREADY(axi_interface_bready),
		.S_AXI_ARADDR(axi_interface_araddr),
		.S_AXI_ARPROT(axi_interface_arprot),
		.S_AXI_ARVALID(axi_interface_arvalid),
		.S_AXI_ARREADY(axi_interface_arready),
		.S_AXI_RDATA(axi_interface_rdata),
		.S_AXI_RRESP(axi_interface_rresp),
		.S_AXI_RVALID(axi_interface_rvalid),
		.S_AXI_RREADY(axi_interface_rready),
		.i2c_clk(i2c_clk),
		.scl_out(scl_out),
		.sda_out(sda_out),
		.sda_in(sda_in),
		.debug(debug)
	);

	// Add user logic here

	// User logic ends

	endmodule
