#include "global.h"
#include "reg.h"
#include "isp1760-regs.h"

#define RW_TEST_VALUE   0x5555aaaa

static u32 isp1760_read32(u32 reg);
static u32 isp1760_write32(u32 reg,u32 Value);

static u32 isp1760_read32(u32 reg)
{
   return REG_RD(USB_1760_ADR + reg) + (REG_RD(USB_1760_ADR + reg + 2) << 16);
}

static u32 isp1760_write32(u32 reg,u32 Value)
{
   REG_WR(USB_1760_ADR + reg,(u16) (Value & 0xffff));
   REG_WR(USB_1760_ADR + reg + 2,(u16) ((Value >> 16) & 0xffff));
}

// Return 1 if USB controller is detected
int UsbProbe(void)
{
   int Ret = FALSE;  // Assume the worse

   do {
      isp1760_write32(HC_SCRATCH_REG,RW_TEST_VALUE);
      if((isp1760_read32(HC_CHIP_ID_REG) & 0xffff) != 0x1761) {
         break;
      }
      if(isp1760_read32(HC_SCRATCH_REG) != RW_TEST_VALUE) {
         break;
      }
#if 0
      isp1760_write32(HC_SCRATCH_REG,~RW_TEST_VALUE);
      if(isp1760_read32(HC_SCRATCH_REG) != ~RW_TEST_VALUE) {
         break;
      }
#endif
      Ret = TRUE;
   } while(FALSE);

   return Ret;
}


