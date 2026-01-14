# Xilinx XUP Blackboard rev D Pinning 
# Additional constraints for keyboard (keyboard_pullups.xdc)
# Jason Losh

# Pmod header A
set_property PULLUP true [get_ports GPIO[2]];
set_property PULLUP true [get_ports GPIO[3]];
set_property PULLUP true [get_ports GPIO[6]];
set_property PULLUP true [get_ports GPIO[7]];
