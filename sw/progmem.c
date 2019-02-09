#include <stdint.h>
#include <math.h>

#include "reg.h"
#include "top_defines.h"
#include "audio.h"
#include "mcp23017.h"
#include "i2c.h"
#include "global.h"

int mcp23017_init(void);

static byte mcp23017_registers[][2] = {
   {REG_IODIRA,     0x7f},      // LED is output
   {REG_IODIRB,     0x7f},      // LED is output
   {REG_GPPUA,      0x7f},      // Enable pull resistors on port A for everything except LED
   {REG_GPPUB,      0x7f},      // Enable pull resistors on port B for everything except LED
   {REG_OLATA,      0x80},      // Enable LED A
   {REG_OLATB,      0x80},      // Enable LED B
   {0xff}
};

int mcp23017_init()
{
   int idx = 0;
   int Ret = 0;

   while(mcp23017_registers[idx][0] != 0xff) {
       byte addr  = mcp23017_registers[idx][0];
       byte value = mcp23017_registers[idx++][1];

       Ret = i2c_write_reg(VGA_I2C_ADR, MCP23017_I2C_ADR, addr,value);
       if(Ret != 1) {
       // i2c_write_reg failed, bail
          break;
       }
   }

   return Ret;
}

int main() 
{
   int cntr = 0;
   int Bits = I2C_INIT_COMPLETE | I2C_AUDIO_ENABLE;

   REG_WR(LED_CONFIG_ADR,1);
   audio_init();
   i2c_init(VGA_I2C_ADR);
   mcp23017_init();

   do {
   // Try to initialize the MCP23017.
      if(!mcp23017_init()) {
      // Init failed, no MCP23017 is present
         break;
      }

   // If we get this far then we have a MCP23017, use it 
      Bits |= I2C_EXPANDER;
      while(1) {
         int toggle_bit = (cntr>>8) & 1;

         i2c_write_reg(VGA_I2C_ADR,MCP23017_I2C_ADR,REG_OLATA,toggle_bit <<7);
         i2c_write_reg(VGA_I2C_ADR,MCP23017_I2C_ADR,REG_OLATB,(~toggle_bit)<<7);

         i2c_read_regs(VGA_I2C_ADR,MCP23017_I2C_ADR,REG_GPIOA,(byte *)&Bits,2);
         REG_WR(GPIO_ADR,Bits);
         ++cntr;
      }
   } while(0);

   REG_WR(GPIO_ADR,Bits);
   while(1);
}

