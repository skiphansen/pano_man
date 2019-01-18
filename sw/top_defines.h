
// Memory map
// A[0:31]     A31 A30 A15    
// 0x00000000  0   0    0  On chip program RAM 
// 0x00008000  0   0    1  On chip video text buffer RAM 
// 0x40000000  0   1    x  FPGA registers
// 0x80000000  1   0    x  USB chip
// 0xc0000000  1   1    x  SDRAM

#define SCL_OFFSET         0
#define SDA_OFFSET         0x4

#define LED_CONFIG_ADR     0x40000000
#define CODEC_I2C_ADR      0x40000010
#define VGA_I2C_ADR        0x40000018
#define GPIO_ADR           0x40000020

#define USB_1760_ADR       0x80000000

// Bits in GPIO register:
#define I2C_AUDIO_ENABLE   0x04000  // bit 14 -> audio enable
#define I2C_EXPANDER       0x10000  // bit 16 -> Port expander present
#define I2C_INIT_COMPLETE  0x20000  // bit 17 -> Initialization complete

#define TXT_BUF_ADR        0x00008000

