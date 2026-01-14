//-----------------------------------------------------------------------------

#include <linux/kernel.h>      // kstrtouint
#include <linux/module.h>      // MODULE_ macros
#include <linux/init.h>        // __init
#include <linux/kobject.h>     // kobject, kobject_atribute,
                               // kobject_create_and_add, kobject_put
#include <asm/io.h>            // iowrite, ioread, ioremap_nocache (platform specific)
#include "address_map.h"       // overall memory map
#include "i2c_regs.h"          // register offsets in IP

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
// Kernel module information
//-----------------------------------------------------------------------------

MODULE_LICENSE("GPL");
MODULE_AUTHOR("Rezwana Karim Roza");
MODULE_DESCRIPTION("I2C Expander");

//-----------------------------------------------------------------------------
// Global variables
//-----------------------------------------------------------------------------

static unsigned int *i2c = NULL;

//-----------------------------------------------------------------------------
// Subroutines
//-----------------------------------------------------------------------------

bool setPin(uint32_t pin, uint32_t bit, uint32_t *bitReg, uint32_t regAddr)
{
    uint32_t control = 0;
    uint32_t status = 0;

    if (pin > 7 || bit > 1) return false;

    *bitReg &= ~(1 << pin);
    *bitReg |= (bit << pin);

    status |= (1 << I2C_STATUS_ACKERR);
    status |= (1 << I2C_STATUS_RESET);

    control = ioread32(i2c + OFS_CONTROL);
    control &= ~(0x1F); // Clear Byte Count and RW bits
    control |= (1) << I2C_CONTROL_BYTECNT; // Set Byte Count
    control |= (0 << I2C_CONTROL_RW); // Set Write
    control |= (1 << I2C_CONTROL_START); // Start Transfer

    while ((ioread32(i2c + OFS_STATUS) & (1 << I2C_STATUS_BUSY)));

    iowrite32(status, i2c + OFS_STATUS);
    iowrite32(MCP_ADDR, i2c + OFS_ADDRESS);
    iowrite32(regAddr, i2c + OFS_REGISTER);
    iowrite32(*bitReg, i2c + OFS_DATA);
    iowrite32(control, i2c + OFS_CONTROL);

    return true;
}

int getPin(uint32_t pin, uint32_t regAddr)
{
    uint32_t control = 0;
    uint32_t status = 0;

    if (pin > 7) return -1;

    status |= (1 << I2C_STATUS_ACKERR);
    status |= (1 << I2C_STATUS_RESET);

    control = ioread32(i2c + OFS_CONTROL);
    control &= ~(0x1F); // Clear Byte Count and RW bits
    control |= (1) << I2C_CONTROL_BYTECNT; // Set Byte Count
    control |= (1 << I2C_CONTROL_RW); // Set Read
    control |= (1 << I2C_CONTROL_START); // Start Transfer

    while ((ioread32(i2c + OFS_STATUS) & (1 << I2C_STATUS_BUSY)));

    iowrite32(status, i2c + OFS_STATUS);
    iowrite32(MCP_ADDR, i2c + OFS_ADDRESS);
    iowrite32(regAddr, i2c + OFS_REGISTER);
    iowrite32(control, i2c + OFS_CONTROL);

    while ((ioread32(i2c + OFS_STATUS) & (1 << I2C_STATUS_RXFE)));
    return (ioread32(i2c + OFS_DATA) >> pin) & 0x1;
}

//-----------------------------------------------------------------------------
// Kernel Objects
//-----------------------------------------------------------------------------

static int data = 0;
static int dir = 0;
static int pullup = 0;

#define PIN_ATTR(name, pin, reg) \
static ssize_t name##pin##Show(struct kobject *kobj, struct kobj_attribute *attr, char *buffer) \
{ \
    int val = getPin(pin, reg); \
    return sprintf(buffer, "%d\n", val); \
} \
static ssize_t name##pin##Store(struct kobject *kobj, struct kobj_attribute *attr, const char *buffer, size_t count) \
{ \
    int val; \
    if (kstrtouint(buffer, 0, &val) == 0) \
        setPin(pin, val, &name, reg); \
    return count; \
} \
static struct kobj_attribute name##pin##Attr = __ATTR(name, 0664, name##pin##Show, name##pin##Store);

#define DEFINE_PIN_ATTRS(pin) \
PIN_ATTR(dir, pin, MCP_REG_IODIR) \
PIN_ATTR(pullup, pin, MCP_REG_GPPU) \
PIN_ATTR(data, pin, MCP_REG_GPIO) \
static struct attribute *attrs##pin[] = {&dir##pin##Attr.attr, &pullup##pin##Attr.attr, &data##pin##Attr.attr, NULL}; \
static struct attribute_group group##pin = {.name = #pin, .attrs = attrs##pin};

// Generate all pins
DEFINE_PIN_ATTRS(0)
DEFINE_PIN_ATTRS(1)
DEFINE_PIN_ATTRS(2)
DEFINE_PIN_ATTRS(3)
DEFINE_PIN_ATTRS(4)
DEFINE_PIN_ATTRS(5)
DEFINE_PIN_ATTRS(6)
DEFINE_PIN_ATTRS(7)

// Top-level kobject
static struct kobject *kobj;

//-----------------------------------------------------------------------------
// Initialization and Exit
//-----------------------------------------------------------------------------

static int __init initialize_module(void)
{
    int result;

    printk(KERN_INFO "I2C Expander: starting\n");

    kobj = kobject_create_and_add("i2c_expander", kernel_kobj);
    if (!kobj)
    {
        printk(KERN_ALERT "I2C Expander: failed to create and add kobj\n");
        return -ENOENT;
    }

    result = sysfs_create_group(kobj, &group0); if (result != 0) return result;
    result = sysfs_create_group(kobj, &group1); if (result != 0) return result;
    result = sysfs_create_group(kobj, &group2); if (result != 0) return result;
    result = sysfs_create_group(kobj, &group3); if (result != 0) return result;
    result = sysfs_create_group(kobj, &group4); if (result != 0) return result;
    result = sysfs_create_group(kobj, &group5); if (result != 0) return result;
    result = sysfs_create_group(kobj, &group6); if (result != 0) return result;
    result = sysfs_create_group(kobj, &group7); if (result != 0) return result;

    i2c = (unsigned int*)ioremap(AXI4_LITE_BASE + I2C_BASE_OFFSET, SPAN_IN_BYTES);
    if (i2c == NULL) return -ENODEV;
    printk(KERN_INFO "I2C Expander: initialized\n");
    return 0;
}

static void __exit exit_module(void)
{
    iounmap(i2c);
    sysfs_remove_group(kobj, &group0);
    sysfs_remove_group(kobj, &group1);
    sysfs_remove_group(kobj, &group2);
    sysfs_remove_group(kobj, &group3);
    sysfs_remove_group(kobj, &group4);
    sysfs_remove_group(kobj, &group5);
    sysfs_remove_group(kobj, &group6);
    sysfs_remove_group(kobj, &group7);
    kobject_put(kobj);
    printk(KERN_INFO "I2C Expander: exit\n");
}

module_init(initialize_module);
module_exit(exit_module);