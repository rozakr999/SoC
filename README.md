# Custom I²C IP Core with Linux Device Drivers

This project implements a complete hardware–software I²C master subsystem on a Xilinx Zynq-based Blackboard FPGA platform, integrating a custom programmable-logic (PL) IP core with Linux running on the processing system (PS). The design demonstrates end-to-end SoC co-design, spanning RTL development, AXI-Lite integration, kernel driver development, and user-space control.

The hardware component is a custom Verilog I²C master IP core that supports standard 7-bit I²C devices and implements START/STOP conditions, ACK/NACK handling, register addressing, repeated-start sequences, and multi-byte transfers using an internal finite-state machine. The IP core exposes a memory-mapped AXI4-Lite interface, enabling Linux to configure and control transactions through simple register reads and writes.

On the software side, the system includes a layered Linux driver stack. A kernel base driver maps the AXI-Lite register space using ioremap() and exposes the I²C core controls through sysfs, allowing user-space interaction without direct register access. A higher-level kernel expander driver abstracts an MCP23008 I/O expander into virtual GPIO pins, each controllable through structured sysfs attributes. A lightweight user-space application provides command-line access for testing, configuration, and validation.

The system was validated using an MCP23008 I/O expander and logic-analyzer measurements, confirming protocol-accurate timing and compliance with TI I²C reference waveforms. The design reliably supports transmit and receive FIFOs, repeated-start transactions, and robust Linux-to-hardware communication.

Technologies: Verilog/SystemVerilog, AXI4-Lite, I²C, Linux Kernel Modules, sysfs, Embedded Linux, FPGA SoC  
Platform: Xilinx Zynq (Blackboard FPGA)  
Course: CSE 5392 – System on Chip Design  
Institution: University of Texas at Arlington  

Author:  
Rezwana Karim Roza
