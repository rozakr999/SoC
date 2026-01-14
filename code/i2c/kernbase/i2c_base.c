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

bool setMode(uint32_t mode)
{
    uint32_t control;
    if (mode < 2)
    {
        control = ioread32(i2c + OFS_CONTROL);      // Read current control register
        control &= ~(1 << I2C_CONTROL_RW);          // Clear mode bit
        control |= (mode << I2C_CONTROL_RW);        // Set mode bit
        while ((ioread32(i2c + OFS_STATUS) & (1 << I2C_STATUS_BUSY)));
        iowrite32(control, i2c + OFS_CONTROL);      // Write back to control register
        return true;
    }
    else
        return false;
}

bool getMode(void)
{
    uint32_t control;
    control = ioread32(i2c + OFS_CONTROL);
    return (control >> I2C_CONTROL_RW) & 0x1;
}

bool setByteCount(uint32_t byte_count)
{
    uint32_t control;
    if (byte_count < 16)
    {
        control = ioread32(i2c + OFS_CONTROL);            // Read current control register
        control &= ~(0xf << I2C_CONTROL_BYTECNT);         // Clear byte count bits
        control |= (byte_count << I2C_CONTROL_BYTECNT);   // Set byte count bits
        while ((ioread32(i2c + OFS_STATUS) & (1 << I2C_STATUS_BUSY)));
        iowrite32(control, i2c + OFS_CONTROL);            // Write back to control register
        return true;
    }
    else
        return false;
}

uint32_t getByteCount(void)
{
    uint32_t control;
    control = ioread32(i2c + OFS_CONTROL);
    return (control >> I2C_CONTROL_BYTECNT) & 0xf;
}

bool setRegister(uint32_t reg)
{
    if (reg < 256)
    {
        while ((ioread32(i2c + OFS_STATUS) & (1 << I2C_STATUS_BUSY)));
        iowrite32(reg, i2c + OFS_REGISTER);
        return true;
    }
    else
        return false;
}

uint32_t getRegister(void)
{
    return ioread32(i2c + OFS_REGISTER) & 0xff;
}

bool setAddress(uint32_t address)
{
    if (address < 128)
    {
        while ((ioread32(i2c + OFS_STATUS) & (1 << I2C_STATUS_BUSY)));
        iowrite32(address, i2c + OFS_ADDRESS);
        return true;
    }
    else
        return false;
}

uint32_t getAddress(void)
{
    return ioread32(i2c + OFS_ADDRESS) & 0x7f;
}

bool setRStart(uint32_t rstart)
{
    uint32_t control;
    if (rstart < 2)
    {
        control = ioread32(i2c + OFS_CONTROL);      // Read current control register
        control &= ~(1 << I2C_CONTROL_RSTART);      // Clear bit
        control |= (rstart << I2C_CONTROL_RSTART);  // Set bit
        while ((ioread32(i2c + OFS_STATUS) & (1 << I2C_STATUS_BUSY)));
        iowrite32(control, i2c + OFS_CONTROL);      // Write back to control register
        return true;
    }
    else
        return false;
}

bool getRStart(void)
{
    uint32_t control;
    control = ioread32(i2c + OFS_CONTROL);
    return (control >> I2C_CONTROL_RSTART) & 0x1;
}

bool setStart(void)
{
    uint32_t control;
    control = ioread32(i2c + OFS_CONTROL);      // Read current control register
    control |= (1 << I2C_CONTROL_START);        // Set bit
    while ((ioread32(i2c + OFS_STATUS) & (1 << I2C_STATUS_BUSY)));
    iowrite32(control, i2c + OFS_CONTROL);      // Write back to control register
    return true;
}

bool getStart(void)
{
    uint32_t control;
    control = ioread32(i2c + OFS_CONTROL);
    return (control >> I2C_CONTROL_START) & 0x1;
}

bool setData(uint32_t data)
{
    if (data < 256)
    {
        iowrite32(data, i2c + OFS_DATA);
        return true;
    }
    else
        return false;
}

uint32_t getData(void)
{
    while ((ioread32(i2c + OFS_STATUS) & (1 << I2C_STATUS_BUSY)));
    return ioread32(i2c + OFS_DATA) & 0xff;
}

//-----------------------------------------------------------------------------
// Kernel Objects
//-----------------------------------------------------------------------------



// mode
// 0: write, 1: read
static int mode = 0;
module_param(mode, int, S_IRUGO);
MODULE_PARM_DESC(mode, " Mode");
static ssize_t mode_store(struct kobject *kobj, struct kobj_attribute *attr, const char *buffer, size_t count)
{
    bool result = kstrtouint(buffer, 0, &mode);
    if (result == 0)
        setMode(mode);
    return count;
}

static ssize_t mode_show(struct kobject *kobj, struct kobj_attribute *attr, char *buffer)
{
    mode = getMode();
    return sprintf(buffer, "%d\n", mode);
}

static struct kobj_attribute mode_attr = __ATTR(mode, 0664, mode_show, mode_store);



// byte_count
// 0-15
static int byte_count = 0;
module_param(byte_count, int, S_IRUGO);
MODULE_PARM_DESC(byte_count, " Byte Count");
static ssize_t byte_count_store(struct kobject *kobj, struct kobj_attribute *attr, const char *buffer, size_t count)
{
    bool result = kstrtouint(buffer, 0, &byte_count);
    if (result == 0)
        setByteCount(byte_count);
    return count;
}

static ssize_t byte_count_show(struct kobject *kobj, struct kobj_attribute *attr, char *buffer)
{
    byte_count = getByteCount();
    return sprintf(buffer, "%d\n", byte_count);
}

static struct kobj_attribute byte_count_attr = __ATTR(byte_count, 0664, byte_count_show, byte_count_store);



// register
// 0-255
static int reg = 0;
module_param(reg, int, S_IRUGO);
MODULE_PARM_DESC(reg, " Register");
static ssize_t register_store(struct kobject *kobj, struct kobj_attribute *attr, const char *buffer, size_t count)
{
    bool result = kstrtouint(buffer, 0, &reg);
    if (result == 0)
        setRegister(reg);
    return count;
}

static ssize_t register_show(struct kobject *kobj, struct kobj_attribute *attr, char *buffer)
{
    reg = getRegister();
    return sprintf(buffer, "%d\n", reg);
}

static struct kobj_attribute register_attr = __ATTR(register, 0664, register_show, register_store);



// address
// 0-127
static int address = 0;
module_param(address, int, S_IRUGO);
MODULE_PARM_DESC(address, " Address");
static ssize_t address_store(struct kobject *kobj, struct kobj_attribute *attr, const char *buffer, size_t count)
{
    bool result = kstrtouint(buffer, 0, &address);
    if (result == 0)
        setAddress(address);
    return count;
}

static ssize_t address_show(struct kobject *kobj, struct kobj_attribute *attr, char *buffer)
{
    address = getAddress();
    return sprintf(buffer, "%d\n", address);
}

static struct kobj_attribute address_attr = __ATTR(address, 0664, address_show, address_store);



// use_repeated_start
// 0-127
static int use_repeated_start = 0;
module_param(use_repeated_start, int, S_IRUGO);
MODULE_PARM_DESC(use_repeated_start, " Use Repeated Start");
static ssize_t rstart_store(struct kobject *kobj, struct kobj_attribute *attr, const char *buffer, size_t count)
{
    bool result = kstrtouint(buffer, 0, &use_repeated_start);
    if (result == 0)
        setRStart(use_repeated_start);
    return count;
}

static ssize_t rstart_show(struct kobject *kobj, struct kobj_attribute *attr, char *buffer)
{
    use_repeated_start = getRStart();
    return sprintf(buffer, "%d\n", use_repeated_start);
}

static struct kobj_attribute use_repeated_start_attr = __ATTR(use_repeated_start, 0664, rstart_show, rstart_store);



// start
// always 1 on write
static int start = 0;
module_param(start, int, S_IRUGO);
MODULE_PARM_DESC(start, " Start");
static ssize_t start_store(struct kobject *kobj, struct kobj_attribute *attr, const char *buffer, size_t count)
{
    bool result = kstrtouint(buffer, 0, &start);
    if (result == 0)
        setStart();
    return count;
}

static ssize_t start_show(struct kobject *kobj, struct kobj_attribute *attr, char *buffer)
{
    start = getStart();
    return sprintf(buffer, "%d\n", start);
}

static struct kobj_attribute start_attr = __ATTR(start, 0664, start_show, start_store);



// tx_data
// write only
// 0-255
static int tx_data = 0;
module_param(tx_data, int, S_IRUGO);
MODULE_PARM_DESC(tx_data, " TX Data");

static ssize_t data_store(struct kobject *kobj, struct kobj_attribute *attr, const char *buffer, size_t count)
{
    uint32_t result = kstrtouint(buffer, 0, &tx_data);
    if (result == 0)
    {
        printk(KERN_INFO "i2c kernel: Data added to TX FIFO\n");
        setData(tx_data);
    }
    return count;
}

static struct kobj_attribute tx_data_attr = __ATTR(tx_data, 0220, NULL, data_store);



// rx_data
// read only
// 0-255
static int rx_data = 0;
module_param(rx_data, int, S_IRUGO);
MODULE_PARM_DESC(rx_data, " Receive Data");

static ssize_t data_show(struct kobject *kobj, struct kobj_attribute *attr, char *buffer)
{
    rx_data = getData();
    return sprintf(buffer, "%d\n", rx_data);
}

static struct kobj_attribute rx_data_attr = __ATTR(rx_data, 0444, data_show, NULL);



// Top-level kobject
static struct kobject *kobj;

//-----------------------------------------------------------------------------
// Initialization and Exit
//-----------------------------------------------------------------------------

static int __init initialize_module(void)
{
    int result;

    printk(KERN_INFO "I2C: starting\n");

    kobj = kobject_create_and_add("i2c", kernel_kobj);
    if (!kobj)
    {
        printk(KERN_ALERT "I2C: failed to create and add kobj\n");
        return -ENOENT;
    }

    result = sysfs_create_file(kobj, &mode_attr.attr);
    if (result) return result;
    result = sysfs_create_file(kobj, &byte_count_attr.attr);
    if (result) return result;
    result = sysfs_create_file(kobj, &register_attr.attr);
    if (result) return result;
    result = sysfs_create_file(kobj, &address_attr.attr);
    if (result) return result;
    result = sysfs_create_file(kobj, &use_repeated_start_attr.attr);
    if (result) return result;
    result = sysfs_create_file(kobj, &start_attr.attr);
    if (result) return result;
    result = sysfs_create_file(kobj, &tx_data_attr.attr);
    if (result) return result;
    result = sysfs_create_file(kobj, &rx_data_attr.attr);
    if (result) return result;

    i2c = (unsigned int*)ioremap(AXI4_LITE_BASE + I2C_BASE_OFFSET, SPAN_IN_BYTES);
    if (i2c == NULL) return -ENODEV;
    printk(KERN_INFO "I2C: initialized\n");
    return 0;
}

static void __exit exit_module(void)
{
    iounmap(i2c);
    sysfs_remove_file(kobj, &mode_attr.attr);
    sysfs_remove_file(kobj, &byte_count_attr.attr);
    sysfs_remove_file(kobj, &register_attr.attr);
    sysfs_remove_file(kobj, &address_attr.attr);
    sysfs_remove_file(kobj, &use_repeated_start_attr.attr);
    sysfs_remove_file(kobj, &start_attr.attr);
    sysfs_remove_file(kobj, &tx_data_attr.attr);
    sysfs_remove_file(kobj, &rx_data_attr.attr);
    kobject_put(kobj);
    printk(KERN_INFO "I2C: exit\n");
}

module_init(initialize_module);
module_exit(exit_module);
