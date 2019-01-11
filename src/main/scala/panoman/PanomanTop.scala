package panoman

import spinal.core._
import spinal.lib.io.{InOutWrapper, TriState}

object PanomanTop {
    def main(args: Array[String]) {
        SpinalVerilog(InOutWrapper(new Pano()))
        println("DONE")
    }
}
