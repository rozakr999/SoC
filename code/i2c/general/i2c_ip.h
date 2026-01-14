#ifndef I2C_H_
#define I2C_H_

#include <stdint.h>
#include <stdbool.h>

//-----------------------------------------------------------------------------
// Register Bit Masking
//-----------------------------------------------------------------------------

#define I2C_STATUS_RXFO         0    // RX FIFO Overflow
#define I2C_STATUS_RXFF         1    // RX FIFO Full
#define I2C_STATUS_RXFE         2    // RX FIFO Empty
#define I2C_STATUS_TXFO         3    // TX FIFO Overflow
#define I2C_STATUS_TXFF         4    // TX FIFO Full
#define I2C_STATUS_TXFE         5    // TX FIFO Empty
#define I2C_STATUS_ACKERR       6    // Acknowledgement Error
#define I2C_STATUS_BUSY         7    // I2C Busy
#define I2C_STATUS_RESET        7    // I2C Reset
#define I2C_STATUS_DEBUGIN      8    // Debug From IP

#define I2C_CONTROL_RW          0    // Read/Write
#define I2C_CONTROL_BYTECNT     1    // Number of Bytes to Transfer
#define I2C_CONTROL_USEREG      5    // Use Register
#define I2C_CONTROL_RSTART      6    // Repeated Start
#define I2C_CONTROL_START       7    // Start Transfer
#define I2C_CONTROL_TESTOUT     8    // Test Output Mode
#define I2C_CONTROL_DEBUGOUT    24   // Debug GPO

#define MCP_REG_IODIR           0
#define MCP_REG_IPOL            1
#define MCP_REG_GPINTEN         2
#define MCP_REG_DEFVAL          3
#define MCP_REG_INTCON          4
#define MCP_REG_IOCON           5
#define MCP_REG_GPPU            6
#define MCP_REG_INTF            7
#define MCP_REG_INTCAP          8
#define MCP_REG_GPIO            9
#define MCP_REG_OLAT            10

#define MCP_ADDR                0x20

#define DEF_USEREG              1
#define DEF_RSTART              1
#define DEF_TESTOUT             0

//-----------------------------------------------------------------------------
// Subroutines
//-----------------------------------------------------------------------------

bool i2cOpen(void);

uint32_t getAddress();
uint32_t getRegister();
uint32_t getData();
uint32_t getStatus();
uint32_t getControl();

void printState(uint8_t state);
bool defaultConfig();

void waitFifoTxSpace();
void waitFifoRxData();

void setAddress(uint32_t value);
void setRegister(uint32_t value);
void setData(uint32_t value);
void setStatus(uint32_t value);
void setControl(uint32_t value);

void clearRxOverflow();
void clearTxOverflow();
void clearAckError();

void i2cInit(bool usereg, bool rstart, bool testout);
void i2cBusyWait();
void i2cWrite(uint8_t address, uint8_t reg, uint8_t data);
void i2cWriteN(uint8_t address, uint8_t reg, uint8_t data[], uint8_t n);
uint8_t i2cRead(uint8_t address, uint8_t reg);
void i2cReadN(uint8_t address, uint8_t reg, uint8_t data[], uint8_t n);

void mcpWrite(uint8_t reg, uint8_t data);
void mcpWriteN(uint8_t reg, uint8_t data[], uint8_t n);
uint8_t mcpRead(uint8_t reg);
void mcpReadN(uint8_t reg, uint8_t data[], uint8_t n);

#endif
