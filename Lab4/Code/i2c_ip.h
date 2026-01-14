#ifndef I2C_H_
#define I2C_H_

#include <stdint.h>
#include <stdbool.h>

//-----------------------------------------------------------------------------
// Subroutines
//-----------------------------------------------------------------------------

bool i2cOpen(void);
uint32_t getData();
void setData(uint32_t value);
uint32_t getStatus();

#endif
