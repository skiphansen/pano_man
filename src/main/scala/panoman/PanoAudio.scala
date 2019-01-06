package panoman

import spinal.core._

class audio() extends BlackBox {
val io = new Bundle {
    var clk12 = in Bool
    var reset12_ = in Bool

    var audio_mclk = out Bool
    var audio_bclk = out Bool
    var audio_dacdat = out Bool
    var audio_daclrc = out Bool
    var audio_adcdat = in Bool
    var audio_adclrc = out Bool
    var audio_sample = in SInt(16 bits)
  }

  // Remove io_ prefix 
  noIoPrefix() 

  addRTLPath("./src/main/pano_rtl/audio.v")
}

