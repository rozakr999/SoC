open_hw
connect_hw_server
open_hw_target
current_hw_device [lindex [get_hw_devices {xc7z*}] 0]
set_property PROGRAM.FILE {Lab3.runs/impl_1/I2C_fifo_Top.bit} [current_hw_device]
program_hw_devices [current_hw_device]
