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
// Subroutines
//-----------------------------------------------------------------------------

uint32_t readFile(const char *path)
{
    uint32_t value = 0;
    FILE *f = fopen(path, "r");
    if (!f) {
        perror("fopen");
        return 0;
    }
    if (fscanf(f, "%u", &value) != 1) {
        printf("Failed to parse value from: %s\n", path);
        fclose(f);
        return 0;
    }
    fclose(f);
    return value;
}

void writeFile(const char *path, uint32_t value)
{
    FILE *f = fopen(path, "w");
    if (!f) {
        perror("fopen");
        return;
    }
    if (fprintf(f, "%u\n", value) < 0) {
        printf("Failed to write value to: %s\n", path);
        fclose(f);
        return;
    }
    fclose(f);
    return;
}

uint32_t readPin(uint32_t pin, const char *type)
{
    char path[256];
    snprintf(path, sizeof(path), "/sys/kernel/i2c_expander/%u/%s", pin, type);
    return readFile(path);
}

void writePin(uint32_t pin, const char *type, uint32_t value)
{
    char path[256];
    snprintf(path, sizeof(path), "/sys/kernel/i2c_expander/%u/%s", pin, type);
    writeFile(path, value);
}

bool getMode()
{
    return (readFile("/sys/kernel/i2c/mode") & 0x1);
}

uint32_t getByteCount()
{
    return (readFile("/sys/kernel/i2c/byte_count") & 0xf);
}

uint32_t getRegister()
{
    return readFile("/sys/kernel/i2c/register");
}

uint32_t getAddress()
{
    return readFile("/sys/kernel/i2c/address");
}

bool getRStart()
{
    return readFile("/sys/kernel/i2c/use_repeated_start");
}

uint32_t getData()
{
    return readFile("/sys/kernel/i2c/rx_data");
}

void setMode(bool mode)
{
    writeFile("/sys/kernel/i2c/mode", mode);
}

void setByteCount(uint32_t byte_count)
{
    writeFile("/sys/kernel/i2c/byte_count", byte_count);
}

void setRegister(uint32_t reg)
{
    writeFile("/sys/kernel/i2c/register", reg);
}

void setAddress(uint32_t address)
{
    writeFile("/sys/kernel/i2c/address", address);
}

void setRStart(bool rstart)
{
    writeFile("/sys/kernel/i2c/use_repeated_start", rstart);
}

void setData(uint32_t data)
{
    writeFile("/sys/kernel/i2c/tx_data", data);
}

void start()
{
    writeFile("/sys/kernel/i2c/start", 1);
}