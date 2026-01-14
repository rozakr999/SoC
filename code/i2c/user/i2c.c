#include <stdlib.h>          // EXIT_ codes
#include <stdio.h>           // printf
#include <string.h>          // strcmp
#include <stdint.h>
#include <unistd.h>
#include "i2c_ip.h"

int main(int argc, char* argv[])
{
    uint32_t value;



    if (argc == 2 && (strcmp(argv[1], "mode") == 0))
        printf("%d\n", getMode());
    else if (argc == 2 && (strcmp(argv[1], "cnt") == 0))
        printf("%d\n", getByteCount());
    else if (argc == 2 && (strcmp(argv[1], "reg") == 0))
        printf("%d\n", getRegister());
    else if (argc == 2 && (strcmp(argv[1], "addr") == 0))
        printf("%d\n", getAddress());
    else if (argc == 2 && (strcmp(argv[1], "rstart") == 0))
        printf("%d\n", getRStart());
    else if (argc == 2 && (strcmp(argv[1], "start") == 0))
        start();
    else if (argc == 2 && (strcmp(argv[1], "data") == 0))
        printf("%d\n", getData());



    else if (argc == 3 && (strcmp(argv[1], "mode") == 0))
        setMode((uint32_t)atoi(argv[2]));
    else if (argc == 3 && (strcmp(argv[1], "cnt") == 0))
        setByteCount((uint32_t)atoi(argv[2]));
    else if (argc == 3 && (strcmp(argv[1], "reg") == 0))
        setRegister((uint32_t)atoi(argv[2]));
    else if (argc == 3 && (strcmp(argv[1], "addr") == 0))
        setAddress((uint32_t)atoi(argv[2]));
    else if (argc == 3 && (strcmp(argv[1], "rstart") == 0))
        setRStart((uint32_t)atoi(argv[2]));
    else if (argc == 3 && (strcmp(argv[1], "data") == 0))
        setData((uint32_t)atoi(argv[2]));


    else if (argc == 4 && (strcmp(argv[1], "pin") == 0) && (strcmp(argv[3], "dir") == 0))
        printf("%d\n", readPin((uint32_t)atoi(argv[2]) & 0x7, "dir"));
    else if (argc == 5 && (strcmp(argv[1], "pin") == 0) && (strcmp(argv[3], "dir") == 0))
        writePin((uint32_t)atoi(argv[2]) & 0x7, "dir", (uint32_t)atoi(argv[4]) & 0x1);
    else if (argc == 4 && (strcmp(argv[1], "pin") == 0) && (strcmp(argv[3], "pull") == 0))
        printf("%d\n", readPin((uint32_t)atoi(argv[2]) & 0x7, "pullup"));
    else if (argc == 5 && (strcmp(argv[1], "pin") == 0) && (strcmp(argv[3], "pull") == 0))
        writePin((uint32_t)atoi(argv[2]) & 0x7, "pullup", (uint32_t)atoi(argv[4]) & 0x1);
    else if (argc == 4 && (strcmp(argv[1], "pin") == 0) && (strcmp(argv[3], "data") == 0))
        printf("%d\n", readPin((uint32_t)atoi(argv[2]) & 0x7, "data"));
    else if (argc == 5 && (strcmp(argv[1], "pin") == 0) && (strcmp(argv[3], "data") == 0))
        writePin((uint32_t)atoi(argv[2]) & 0x7, "data", (uint32_t)atoi(argv[4]) & 0x1);

    else if (argc == 2 && (strcmp(argv[1], "stopgo1") == 0))
    {
        // GPIO[0] <---> RED LED <-------> 330 ohm <---> GND
        // GPIO[1] <---> GREEN LED <-----> 330 ohm <---> GND
        // GPIO[2] <---> PUSH BUTTON <---> GND

        // uint8_t LEDR_MASK = 0b00000001;
        // uint8_t LEDG_MASK = 0b00000010;
        // uint8_t PB_MASK   = 0b00000100;

        uint32_t go = 1;

        setRStart(1);
        setByteCount(1);
        setAddress(MCP_ADDR);

        // Set Output: GPIO1 and GPIO 0
        // Set Input: GPIO2
        setMode(0);
        setRegister(MCP_REG_IODIR);
        setData(0b11111100);
        start();

        // Enable pull-up on GPIO2
        setMode(0);
        setRegister(MCP_REG_GPPU);
        setData(0b00000100); 
        start();

        // Turn on RED LED
        setMode(0);
        setRegister(MCP_REG_GPIO);
        setData(0b00000001);
        start();

        printf("Running stop go.....\n");

        while (go)
        {
            // Turn on GREEN LED, turn off RED LED
            setMode(1);
            setRegister(MCP_REG_GPIO);
            start();
            go = (getData() & 0b00000100); // Read PB state
        }

        // Turn off GREEN LED, turn on RED LED
        setMode(0);
        setRegister(MCP_REG_GPIO);
        setData(0b00000010);
        start();

        printf("Stop go complete!\n");
    }

    else if (argc == 2 && (strcmp(argv[1], "stopgo2") == 0))
    {
        // GPIO[0] <---> RED LED <-------> 330 ohm <---> GND
        // GPIO[1] <---> GREEN LED <-----> 330 ohm <---> GND
        // GPIO[2] <---> PUSH BUTTON <---> GND

        // uint8_t LEDR_MASK = 0b00000001;
        // uint8_t LEDG_MASK = 0b00000010;
        // uint8_t PB_MASK   = 0b00000100;

        writePin(0, "dir", 0); // GPIO0 output
        writePin(1, "dir", 0); // GPIO1 output
        writePin(2, "dir", 1); // GPIO2 input

        writePin(0, "data", 1);   // Turn on RED LED
        writePin(1, "data", 0);   // Turn off GREEN LED
        writePin(2, "pullup", 1); // Enable pull-up on GPIO2

        // No rate limiting needed for since kernel handles it
        // for pin level access
        printf("Running stop go.....\n");
        while (readPin(2, "data"));

        writePin(0, "data", 0); // Turn off RED LED
        writePin(1, "data", 1); // Turn on GREEN LED
        printf("Stop go complete!\n");
    }


    else if (argc == 2 && (strcmp(argv[1], "-h") == 0 || strcmp(argv[1], "--help") == 0))
    {
        printf("   usage:\n");
        printf("   ./i2c mode                              get the mode value\n");
        printf("   ./i2c mode {value}                      set the mode value\n");
        printf("   ./i2c cnt                               get the byte count value\n");
        printf("   ./i2c cnt {value}                       set the byte count value\n");
        printf("   ./i2c reg                               get the register value\n");
        printf("   ./i2c reg {value}                       set the register value\n");
        printf("   ./i2c addr                              get the address value\n");
        printf("   ./i2c addr {value}                      set the address value\n");
        printf("   ./i2c rstart                            get the use_repeated_start value\n");
        printf("   ./i2c rstart {value}                    set the use_repeated_start value\n");
        printf("   ./i2c start                             start the transaction\n");
        printf("   ./i2c data                              get the rx_data value\n");
        printf("   ./i2c data {value}                      set the tx_data value\n");
        printf("\n");
        printf("   ./i2c pin {pin} dir                     read pin direction value\n");
        printf("   ./i2c pin {pin} dir {value}             write pin direction value\n");
        printf("   ./i2c pin {pin} pull                    read pin pull-up value\n");
        printf("   ./i2c pin {pin} pull {value}            write pin pull-up value\n");
        printf("   ./i2c pin {pin} data                    read pin data\n");
        printf("   ./i2c pin {pin} data {value}            write pin data\n");
        printf("\n");
        printf("   ./i2c stopgo1                           test stop go 1\n");
        printf("   ./i2c stopgo2                           test stop go 2\n");
        printf(" where {pin} is 0-7\n");
    }

    else
    {
        printf("Error: Command not recognized.\n");
        printf("Use '-h' or '--help' to see available commands.\n");
    }

    return EXIT_SUCCESS;
}

