package panoman

import spinal.core._

class Pacman() extends BlackBox {
val io = new Bundle {
    var O_VIDEO_R = out UInt(4 bits)
    var O_VIDEO_G = out UInt(4 bits)
    var O_VIDEO_B = out UInt(4 bits)
    var O_HSYNC = out Bool
    var O_VSYNC = out Bool
    var O_AUDIO = out SInt(8 bits)
    var O_BLANK = out Bool
    var I_JOYSTICK_A = in UInt(8 bits)
    var I_JOYSTICK_B = in UInt(8 bits)
    var I_SW = in UInt(8 bits)
    var O_LED = out UInt(3 bits)
    var I_RESET = in Bool
    var ena_12 = in Bool
    var ena_6 = in Bool
    var clk = in Bool
  }

  // Remove io_ prefix 
  noIoPrefix() 

}
