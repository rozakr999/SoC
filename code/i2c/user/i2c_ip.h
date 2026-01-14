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

uint32_t readFile(const char *path);
void writeFile(const char *path, uint32_t value);
uint32_t readPin(uint32_t pin, const char *type);
void writePin(uint32_t pin, const char *type, uint32_t value);

bool getMode();
uint32_t getByteCount();
uint32_t getRegister();
uint32_t getAddress();
bool getRStart();
uint32_t getData();

void setMode(bool mode);
void setByteCount(uint32_t byte_count);
void setRegister(uint32_t reg);
void setAddress(uint32_t address);
void setRStart(bool rstart);
void setData(uint32_t data);

void start();

#endif