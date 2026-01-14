

proc generate {drv_handle} {
	xdefine_include_file $drv_handle "xparameters.h" "i2c" "NUM_INSTANCES" "DEVICE_ID"  "C_AXI_Interface_BASEADDR" "C_AXI_Interface_HIGHADDR"
}
