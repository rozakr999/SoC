#include <stdlib.h>          // EXIT_ codes
#include <stdio.h>           // printf
#include <string.h>          // strcmp
#include <stdint.h>
#include "i2c_ip.h"

int main(int argc, char* argv[])
{
    uint32_t value;
    bool usereg;
    bool rstart;
    bool testout;

    i2cOpen();

    if (!defaultConfig())
        printf("Warning: Detected non-default i2c configuration!\n");

    if (argc == 2 && (strcmp(argv[1], "reset") == 0))
    {
        printf("Resetting state machine and both FIFOs...\n");
        setStatus(1 << I2C_STATUS_RESET);
    }

    else if (argc == 2 && (strcmp(argv[1], "init") == 0))
    {
        usereg = true;
        rstart = true;
        testout = false;

        i2cInit(usereg, rstart, testout);
        printf("Initializing default i2c...\n");
        printf("Use Register:  %s\n", usereg ? "True" : "False");
        printf("Repeat Start:  %s\n", rstart ? "True" : "False");
        printf("CLK Test Out:  %s\n", testout ? "True" : "False");
    }

    else if (argc == 5 && (strcmp(argv[1], "init") == 0))
    {
        usereg = atoi(argv[2]);
        rstart = atoi(argv[3]);
        testout = atoi(argv[4]);

        if (usereg != DEF_USEREG || rstart != DEF_RSTART || testout != DEF_TESTOUT)
            printf("Warning: Setting non-default i2c configuration!\n");

        i2cInit(usereg, rstart, testout);
        printf("Initializing custom i2c...\n");
        printf("Use Register:  %s\n", usereg ? "True" : "False");
        printf("Repeat Start:  %s\n", rstart ? "True" : "False");
        printf("CLK Test Out:  %s\n", testout ? "True" : "False");
    }

    else if (argc == 3 && (strcmp(argv[1], "clear") == 0) && (strcmp(argv[2], "rx") == 0))
    {
        clearRxOverflow();
        printf("Clearing RX FIFO overflow...\n");
    }

    else if (argc == 3 && (strcmp(argv[1], "clear") == 0) && (strcmp(argv[2], "tx") == 0))
    {
        clearTxOverflow();
        printf("Clearing TX FIFO overflow...\n");
    }

    else if (argc == 3 && (strcmp(argv[1], "clear") == 0) && (strcmp(argv[2], "ack") == 0))
    {
        clearAckError();
        printf("Clearing acknowledgment error...\n");
    }

    else if (argc == 2 && (strcmp(argv[1], "dir") == 0))
    {
        value = mcpRead(MCP_REG_IODIR);
        printf("Reading Direction Register: 0x%X\n", value);
    }

    else if (argc == 3 && (strcmp(argv[1], "dir") == 0))
    {
        value = strtol(argv[2], NULL, 16);
        mcpWrite(MCP_REG_IODIR, value);
        printf("Writting Direction Register: 0x%X\n", value);
    }

    else if (argc == 2 && (strcmp(argv[1], "pullup") == 0))
    {
        value = mcpRead(MCP_REG_GPPU);
        printf("Reading Pullup Register: 0x%X\n", value);
    }

    else if (argc == 3 && (strcmp(argv[1], "pullup") == 0))
    {
        value = strtol(argv[2], NULL, 16);
        mcpWrite(MCP_REG_GPPU, value);
        printf("Writting Pullup Register: 0x%X\n", value);
    }

    else if (argc == 2 && (strcmp(argv[1], "data") == 0))
    {
        value = mcpRead(MCP_REG_GPIO);
        printf("Reading Data Register: 0x%X\n", value);
    }

    else if (argc == 3 && (strcmp(argv[1], "data") == 0))
    {
        value = strtol(argv[2], NULL, 16);
        mcpWrite(MCP_REG_GPIO, value);
        printf("Writting Data Register: 0x%X\n", value);
    }

    else if (argc == 2 && (strcmp(argv[1], "stopgo") == 0))
    {
        // GPIO[0] <---> RED LED <-------> 330 ohm <---> GND
        // GPIO[1] <---> GREEN LED <-----> 330 ohm <---> GND
        // GPIO[2] <---> PUSH BUTTON <---> GND

        uint8_t LEDR_MASK = 0b00000001;
        uint8_t LEDG_MASK = 0b00000010;
        uint8_t PB_MASK   = 0b00000100;

        printf("Running stop go.....\n");

        mcpWrite(MCP_REG_IODIR, ~(LEDR_MASK | LEDG_MASK));
        mcpWrite(MCP_REG_GPPU, PB_MASK);
        mcpWrite(MCP_REG_GPIO, LEDR_MASK);
        while (mcpRead(MCP_REG_GPIO) & PB_MASK);
        mcpWrite(MCP_REG_GPIO, LEDG_MASK);

        printf("Stop go complete!\n");
    }

    else if (argc == 3 && (strcmp(argv[1], "bad") == 0) && (strcmp(argv[2], "write") == 0))
    {
        printf("Testing write to wrong address (0xA2)...\n");
        i2cWrite(0xA2, 0x00, 0xFF);
        printf("Done. Check for ACK error in status register.\n");
    }

    else if (argc == 2 && (strcmp(argv[1], "addr") == 0))
    {
        printf("%d\n", getAddress());
    }

    else if (argc == 2 && (strcmp(argv[1], "status") == 0))
    {
        value = getStatus();
        printf("---------- Status ----------\n");
        printf("RX FIFO Overflow:  %u\n", (value >> 0) & 1);
        printf("RX FIFO Full:      %u\n", (value >> 1) & 1);
        printf("RX FIFO Empty:     %u\n", (value >> 2) & 1);
        printf("TX FIFO Overflow:  %u\n", (value >> 3) & 1);
        printf("TX FIFO Full:      %u\n", (value >> 4) & 1);
        printf("TX FIFO Empty:     %u\n", (value >> 5) & 1);
        printf("ACK Error:         %u\n", (value >> 6) & 1);
        printf("Busy:              %u\n", (value >> 7) & 1);
        printf("State:             "); printState((value >> 8) & 0x0F); printf("\n");
        printf("TX FIFO Count:     %u\n", (value >> 16) & 0xF);
        printf("RX FIFO Count:     %u\n", (value >> 20) & 0xF);
    }

    else if (argc == 2 && (strcmp(argv[1], "-h") == 0 || strcmp(argv[1], "--help") == 0))
    {
        printf("   usage:\n");
        printf("   ./i2c reset                             reset state machine and both fifos\n");
        printf("   ./i2c init                              initialize i2c with default config\n");
        printf("   ./i2c init {usereg} {rstart} {testout}  initialize i2c with custom config\n");
        printf("   ./i2c init 1 1 0                        {usereg=1} {rstart=1} {testout=0}\n");
        printf("   ./i2c clear rx                          clear rx fifo overflow flag\n");
        printf("   ./i2c clear tx                          clear tx fifo overflow flag\n");
        printf("   ./i2c clear ack                         clear acknowledgement error\n");
        printf("   ./i2c dir                               print the direction register\n");
        printf("   ./i2c dir {hex value}                   set the direction register\n");
        printf("   ./i2c pullup                            print the pullup register\n");
        printf("   ./i2c pullup {hex value}                set the pullup register\n");
        printf("   ./i2c data                              print the data register\n");
        printf("   ./i2c data {hex value}                  set the data register\n");
        printf("   ./i2c stopgo                            stop go test\n");
        printf("   ./i2c bad write                         test write to wrong address\n");
        printf("   ./i2c status                            print the i2c ip status\n");
        printf("\n");
    }

    else
    {
        printf("Error: Command not recognized.\n");
        printf("Use '-h' or '--help' to see available commands.\n");
    }

    return EXIT_SUCCESS;
}

