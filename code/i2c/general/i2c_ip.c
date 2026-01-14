#include <stdint.h>          // C99 integer types -- uint32_t
#include <stdio.h>           // printf
#include <stdbool.h>         // bool
#include <fcntl.h>           // open
#include <sys/mman.h>        // mmap
#include <unistd.h>          // close
#include "address_map.h"     // address map
#include "i2c_ip.h"          // i2c
#include "i2c_regs.h"        // registers

//-----------------------------------------------------------------------------
// Global variables
//-----------------------------------------------------------------------------

uint32_t *base = NULL;

//-----------------------------------------------------------------------------
// Subroutines
//-----------------------------------------------------------------------------

bool i2cOpen()
{
    // Open /dev/mem
    int file = open("/dev/mem", O_RDWR | O_SYNC);
    bool bOK = (file >= 0);
    if (bOK)
    {
        // Create a map from the physical memory location of
        // /dev/mem at an offset to LW avalon interface
        // with an aperature of SPAN_IN_BYTES bytes
        // to any location in the virtual 32-bit memory space of the process
        base = mmap(NULL, SPAN_IN_BYTES, PROT_READ | PROT_WRITE, MAP_SHARED,
                    file, AXI4_LITE_BASE + I2C_BASE_OFFSET);
        bOK = (base != MAP_FAILED);

        // Close /dev/mem
        close(file);
    }
    return bOK;
}

uint32_t getAddress()
{
    uint32_t value = *(base+OFS_ADDRESS);
    return value;
}

uint32_t getRegister()
{
    uint32_t value = *(base+OFS_REGISTER);
    return value;
}

uint32_t getData()
{
    uint32_t value = *(base+OFS_DATA);
    return value;
}

uint32_t getStatus()
{
    uint32_t value = *(base+OFS_STATUS);
    return value;
}

uint32_t getControl()
{
    uint32_t value = *(base+OFS_CONTROL);
    return value;
}

bool defaultConfig()
{
    uint32_t value = getControl();
    bool usereg = (value >> I2C_CONTROL_USEREG) & 0x1;
    bool rstart = (value >> I2C_CONTROL_RSTART) & 0x1;
    bool testout = (value >> I2C_CONTROL_TESTOUT) & 0x1;
    return (usereg == DEF_USEREG) && (rstart == DEF_RSTART) && (testout == DEF_TESTOUT);
}

void printState(uint8_t state)
{
    switch (state)
    {
        case 0: printf("IDLE"); break;
        case 1: printf("START"); break;
        case 2: printf("STOP"); break;
        case 3: printf("RD_STOP"); break;
        case 4: printf("RD_START"); break;
        case 5: printf("TX_ADDR"); break;
        case 6: printf("TX_REG"); break;
        case 7: printf("TX_DATA"); break;
        case 8: printf("RD_TX_ADDR"); break;
        case 9: printf("RD_RX_DATA"); break;
        default: printf("UNKNOWN"); break;
    }
    return;
}

void waitFifoTxSpace()
{
    while (getStatus() & (1 << I2C_STATUS_TXFF))
    {
        // wait
    }
}

void waitFifoRxData()
{
    while ((getStatus() & (1 << I2C_STATUS_RXFE)))
    {
        // wait
    }
}

void setAddress(uint32_t value)
{
    *(base+OFS_ADDRESS) = value;
}

void setRegister(uint32_t value)
{
    *(base+OFS_REGISTER) = value;
}

void setData(uint32_t value)
{
    *(base+OFS_DATA) = value;
}

void setStatus(uint32_t value)
{
    *(base+OFS_STATUS) = value;
}

void setControl(uint32_t value)
{
    *(base+OFS_CONTROL) = value;
}

void clearRxOverflow()
{
    setStatus(1 << I2C_STATUS_RXFO);
}

void clearTxOverflow()
{
    setStatus(1 << I2C_STATUS_TXFO);
}

void clearAckError()
{
    setStatus(1 << I2C_STATUS_ACKERR);
}

void i2cInit(bool usereg, bool rstart, bool testout)
{
    uint32_t control = 0;
    control |= (usereg) << I2C_CONTROL_USEREG;
    control |= (rstart) << I2C_CONTROL_RSTART;
    control |= (testout) << I2C_CONTROL_TESTOUT;
    setControl(control);
}

void i2cBusyWait()
{
    while (getStatus() & (1 << I2C_STATUS_BUSY))
    {
        // wait
    }
}

void i2cWrite(uint8_t address, uint8_t reg, uint8_t data)
{
    uint32_t control = 0;
    control = getControl();
    control &= ~(0x1F); // Clear Byte Count and RW bits
    control |= (1 << I2C_CONTROL_BYTECNT); // Set Byte Count
    control |= (0 << I2C_CONTROL_RW); // Set Write
    control |= (1 << I2C_CONTROL_START); // Start Transfer

    waitFifoTxSpace();
    setData(data);

    i2cBusyWait();
    setAddress(address & 0x7f);
    setRegister(reg);
    setControl(control);
}

void i2cWriteN(uint8_t address, uint8_t reg, uint8_t data[], uint8_t n)
{
    uint32_t control = 0;
    control = getControl();
    control &= ~(0x1F); // Clear Byte Count and RW bits
    control |= ((n & 0xf) << I2C_CONTROL_BYTECNT); // Set Byte Count
    control |= (0 << I2C_CONTROL_RW); // Set Write
    control |= (1 << I2C_CONTROL_START); // Start Transfer

    for (int i=0; i<n; i++)
    {
        waitFifoTxSpace();
        setData(data[i]);
    }

    i2cBusyWait();
    setAddress(address & 0x7f);
    setRegister(reg);
    setControl(control);
}

uint8_t i2cRead(uint8_t address, uint8_t reg)
{
    uint8_t value;

    uint32_t control = 0;
    control = getControl();
    control &= ~(0x1F); // Clear Byte Count and RW bits
    control |= (1 << I2C_CONTROL_BYTECNT); // Set Byte Count
    control |= (1 << I2C_CONTROL_RW); // Set Read
    control |= (1 << I2C_CONTROL_START); // Start Transfer

    i2cBusyWait();
    setAddress(address & 0x7f);
    setRegister(reg);
    setControl(control);

    waitFifoRxData();
    value = getData() & 0xff;
    return value;
}

void i2cReadN(uint8_t address, uint8_t reg, uint8_t data[], uint8_t n)
{
    uint32_t control = 0;
    control = getControl();
    control &= ~(0x1F); // Clear Byte Count and RW bits
    control |= ((n & 0xf) << I2C_CONTROL_BYTECNT); // Set Byte Count
    control |= (1 << I2C_CONTROL_RW); // Set Read
    control |= (1 << I2C_CONTROL_START); // Start Transfer

    i2cBusyWait();
    setAddress(address & 0x7f);
    setRegister(reg);
    setControl(control);

    for (int i=0; i<n; i++)
    {
        waitFifoRxData();
        data[i] = getData();
    }
}

void mcpWrite(uint8_t reg, uint8_t data)
{
    i2cWrite(MCP_ADDR, reg, data);
}

void mcpWriteN(uint8_t reg, uint8_t data[], uint8_t n)
{
    i2cWriteN(MCP_ADDR, reg, data, n);
}

uint8_t mcpRead(uint8_t reg)
{
    return i2cRead(MCP_ADDR, reg);
}

void mcpReadN(uint8_t reg, uint8_t data[], uint8_t n)
{
    i2cReadN(MCP_ADDR, reg, data, n);
}
