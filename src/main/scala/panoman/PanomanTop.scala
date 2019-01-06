package panoman

import spinal.core._
import spinal.lib.io.{InOutWrapper, TriState}

object PanomanTop {
    def main(args: Array[String]) {

        val config = SpinalConfig()
        config.generateVerilog({
            val toplevel = new Pano()
            InOutWrapper(toplevel)
            toplevel
        })
        println("DONE")
    }
}
