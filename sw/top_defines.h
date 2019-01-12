#define SCL_OFFSET         0
#define SDA_OFFSET         0x4

#define LED_CONFIG_ADR     0x00000000
#define CODEC_I2C_ADR      0x00000010
#define VGA_I2C_ADR        0x00000018
#define GPIO_ADR           0x00000020

// Bits in GPIO register:
#define I2C_AUDIO_ENABLE   0x04000  // bit 14 -> audio enable
#define I2C_EXPANDER       0x10000  // bit 16 -> Port expander present
#define I2C_INIT_COMPLETE  0x20000  // bit 17 -> Initialization complete

#define TXT_BUF_ADR        0x00008000

