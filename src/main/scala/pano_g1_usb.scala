package panoman

import spinal.core._
import spinal.lib.{master, slave}
import spinal.lib.io.{ReadableOpenDrain, TriStateArray, TriState}

class PanoG1Usb() extends Component {
    val io = new Bundle {
        val clkin  = in(Bool)
        val reset_ = in(Bool)
	val a      = out(UInt(17 bits))
        val d	   = slave(TriStateArray(16 bits))
	val irq    = out(Bool)
    }
}

