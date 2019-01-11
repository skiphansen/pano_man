#include <stdint.h>
#include <math.h>

#include "reg.h"
#include "top_defines.h"
#include "audio.h"
#include "mcp23017.h"
#include "i2c.h"
#include "global.h"

void mcp23017_init(void);

static byte mcp23017_registers[][2] = {
   {REG_GPPUA, 0xff},      // Enable pull resistors on port A
   {REG_IODIRB, 0},        // Port B to output mode
   {0xff}
};

void mcp23017_init()
{
   int idx = 0;

   i2c_init(VGA_I2C_ADR);

   while(mcp23017_registers[idx][0] != 0xff){
       byte addr  = mcp23017_registers[idx][0];
       byte value = mcp23017_registers[idx][1];

       i2c_write_reg(VGA_I2C_ADR, MCP23017_I2C_ADR, addr,value);
       ++idx;
   }
}

int main() 
{
   byte Data = 0xff;
   int Bits = I2C_INIT_COMPLETE;

   REG_WR(LED_CONFIG_ADR,1);
// audio_init();
   REG_WR(LED_CONFIG_ADR,0);
   REG_WR(LED_CONFIG_ADR,1);
   REG_WR(LED_CONFIG_ADR,0);

   mcp23017_init();
#if 1
// Copy port A bits to port B 
   while(1) {
      byte Test;
      i2c_read_regs(VGA_I2C_ADR,MCP23017_I2C_ADR,REG_GPIOA,&Test,1);
      i2c_write_regs(VGA_I2C_ADR,MCP23017_I2C_ADR,REG_OLATB,&Test,1);
   }
#else
   do {
   // Try to initialize the MCP23017.  The default configuration is fine
   // except we need to enable pullup resistors
      if(!i2c_write_regs(VGA_I2C_ADR,MCP23017_I2C_ADR,REG_GPPUA,&Data,1)) {
         break;
      }

      if(!i2c_write_regs(VGA_I2C_ADR,MCP23017_I2C_ADR,REG_GPPUB,&Data,1)) {
         break;
      }

   // If we get this far then we have a MCP23017, use it 
      Bits |= I2C_EXPANDER;
      while(1) {
         i2c_read_regs(VGA_I2C_ADR,MCP23017_I2C_ADR,REG_GPIOA,(byte *)&Bits,2);
         REG_WR(GPIO_ADR,Bits);
      }
   } while(0);
#endif
   REG_WR(GPIO_ADR,Bits);
   while(1);
}



