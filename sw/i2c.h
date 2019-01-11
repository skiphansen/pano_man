#ifndef I2C_H
#define I2C_H

#include "global.h"

#define MCP23017_I2C_ADR      0x40
#define WM8750L_I2C_ADR       0x34

void i2c_init(int Port);
void i2c_dly();
void i2c_start(int Port);
void i2c_stop(int Port);
unsigned char i2c_rx(int Port, char ack);
int i2c_tx(int Port, unsigned char d);
int i2c_write_buf(int Port, byte addr, byte* data, int len);
int i2c_read_buf(int Port, byte addr, byte *data, int len);
int i2c_write_reg_nr(int Port, byte addr, byte reg_nr);
int i2c_write_reg(int Port, byte addr, byte reg_nr, byte value);
int i2c_write_regs(int Port, byte addr, byte reg_nr, byte *values, int len);
int i2c_read_reg(int Port, byte addr, byte reg_nr, byte *value);
int i2c_read_regs(int Port, byte addr, byte reg_nr, byte *values, int len);

#endif
