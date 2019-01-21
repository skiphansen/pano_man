#include <stdint.h>
#include <math.h>

#include "reg.h"
#include "top_defines.h"
#include "audio.h"
#include "mcp23017.h"
#include "i2c.h"
#include "g1_usb.h"
#include "global.h"

int mcp23017_init(void);

static byte mcp23017_registers[][2] = {
   {REG_GPPUA, 0xff},      // Enable pull resistors on port A
   {REG_GPPUB, 0xff},      // Enable pull resistors on port B
   {0xff}
};

int mcp23017_init()
{
   int idx = 0;
   int Ret = 0;

   i2c_init(VGA_I2C_ADR);

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
   byte Data = 0xff;
   int Bits = I2C_INIT_COMPLETE | I2C_AUDIO_ENABLE;
   byte Toggle = 0;

   audio_init();

   do {
   // Try to initialize the MCP23017.  The default configuration is fine
   // except we need to enable pullup resistors
      if(!mcp23017_init()) {
      // Init failed, no MCP23017 is present
         break;
      }

   // If we get this far then we have a MCP23017, use it 
      Bits |= I2C_EXPANDER;
      while(1) {
         i2c_read_regs(VGA_I2C_ADR,MCP23017_I2C_ADR,REG_GPIOA,(byte *)&Bits,2);
         REG_WR(GPIO_ADR,Bits);
      }
   } while(0);

   REG_WR(GPIO_ADR,Bits);
   while(1) {
      if(UsbProbe()) {
         Toggle = Toggle ? 0 : 1;
//         REG_WR(LED_CONFIG_ADR,Toggle);
      }
      else {
//         REG_WR(LED_CONFIG_ADR,1);
      }
   }
}



