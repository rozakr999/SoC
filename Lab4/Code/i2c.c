#include <stdlib.h>          // EXIT_ codes
#include <stdio.h>           // printf
#include <string.h>          // strcmp
#include <stdint.h>
#include "i2c_ip.h"         // GPIO IP library

int main(int argc, char* argv[])
{
    uint32_t value;

    if (argc == 2 && (strcmp(argv[1], "read") == 0))
    {
        i2cOpen();
        value = getData();
        printf("Value Retrieved = %u\n", value);
    }
    
    else if (argc == 3 && (strcmp(argv[1], "write") == 0))
    {
        i2cOpen();
        value = atoi(argv[2]);
        setData(value);
        printf("Value Set = %u\n", value);
    }

    else if (argc == 2 && (strcmp(argv[1], "status") == 0))
    {
        i2cOpen();
        value = getStatus();
        printf("---------- Status Flags ----------\n");
        printf("FIFO Overflow: %u\n", (value >> 3) & 1);
        printf("FIFO Full:     %u\n", (value >> 4) & 1);
        printf("FIFO Empty:    %u\n", (value >> 5) & 1);
    }

    else if (argc == 2 && (strcmp(argv[1], "-h") == 0 || strcmp(argv[1], "--help") == 0))
    {
        printf("  usage:\n");
        printf("  i2c read               read the fifo\n");
        printf("  i2c write {uint}       write to fifo\n");
        printf("  \n");
    }
    else
        printf("command not understood\n");

    return EXIT_SUCCESS;
}

