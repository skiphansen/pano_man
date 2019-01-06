package panoman

import spinal.core._

class Pacman_clk() extends BlackBox {
val io = new Bundle {
    val CLKIN_IN = in  Bool 
    val CLKFX_OUT = out Bool 
    var CLKIN_IBUFG_OUT = out Bool
    var CLK0_OUT = out Bool
  }

  // Remove io_ prefix 
  noIoPrefix() 
}

class Pacman_clk1() extends BlackBox {
val io = new Bundle {
    val CLKIN_IN = in  Bool 
    val CLKDV_OUT = out Bool 
    var CLK0_OUT = out Bool
  }

  // Remove io_ prefix 
  noIoPrefix() 
}

