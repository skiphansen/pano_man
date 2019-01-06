
package mr1

import java.nio.file.{Files, Paths}
import spinal.core._
import spinal.lib.master
import spinal.lib.io.ReadableOpenDrain

import panoman._

class MR1Top(config: MR1Config ) extends Component {

    val io = new Bundle {
        val led1    = out(Bool)
        val led2    = out(Bool)
        val led3    = out(Bool)

        val switch_ = in(Bool)


        val txt_buf_wr      = out(Bool)
        val txt_buf_wr_addr = out(UInt(11 bits))
        val txt_buf_wr_data = out(Bits(8 bits))

        val eof         = in(Bool)

        val codec_scl = master(ReadableOpenDrain(Bool))
        val codec_sda = master(ReadableOpenDrain(Bool))
    }

    val mr1 = new MR1(config)

    val wmask = mr1.io.data_req.size.mux(

                    B"00"   -> B"0001",
                    B"01"   -> B"0011",
                    default -> B"1111") |<< mr1.io.data_req.addr(1 downto 0)

    mr1.io.instr_req.ready := True
    mr1.io.instr_rsp.valid := RegNext(mr1.io.instr_req.valid) init(False)

    val cpu_ram_rd_data = Bits(32 bits)
    val reg_rd_data     = Bits(32 bits)

    mr1.io.data_req.ready := True
    mr1.io.data_rsp.valid := RegNext(mr1.io.data_req.valid && !mr1.io.data_req.wr) init(False)
    mr1.io.data_rsp.data  := cpu_ram_rd_data

    val ramSize = 8192

    val ram = if (true) new Area{

        val byteArray = Files.readAllBytes(Paths.get("sw/progmem8k.bin"))
        val cpuRamContent = for(i <- 0 until ramSize/4) yield {
                B( (byteArray(4*i).toLong & 0xff) + ((byteArray(4*i+1).toLong & 0xff)<<8) + ((byteArray(4*i+2).toLong & 0xff)<<16) + ((byteArray(4*i+3).toLong & 0xff)<<24), 32 bits)
        }

        val cpu_ram = Mem(Bits(32 bits), initialContent = cpuRamContent)

        mr1.io.instr_rsp.data := cpu_ram.readSync(
                enable  = mr1.io.instr_req.valid,
                address = (mr1.io.instr_req.addr >> 2).resized
            )

        cpu_ram_rd_data := cpu_ram.readWriteSync(
                enable  = mr1.io.data_req.valid && !mr1.io.data_req.addr(19),
                address = (mr1.io.data_req.addr >> 2).resized,
                write   = mr1.io.data_req.wr,
                data    = mr1.io.data_req.data,
                mask    = wmask
            )
    }
    else new Area{
        val cpu_ram = new cpu_ram()

        cpu_ram.io.address_a     := (mr1.io.instr_req.addr >> 2).resized
        cpu_ram.io.wren_a        := False
        cpu_ram.io.data_a        := 0
        mr1.io.instr_rsp.data    := cpu_ram.io.q_a


        cpu_ram.io.address_b     := (mr1.io.data_req.addr >> 2).resized
        cpu_ram.io.wren_b        := mr1.io.data_req.valid && mr1.io.data_req.wr && !mr1.io.data_req.addr(19)
        cpu_ram.io.byteena_b     := wmask
        cpu_ram.io.data_b        := mr1.io.data_req.data
        mr1.io.data_rsp.data     := cpu_ram.io.q_b
    }

    val update_leds = mr1.io.data_req.valid && mr1.io.data_req.wr && (mr1.io.data_req.addr === U"32'h00080000")

    io.led1 := RegNextWhen(mr1.io.data_req.data(0), update_leds) init(False)
    io.led2 := RegNextWhen(mr1.io.data_req.data(1), update_leds) init(False)
    io.led3 := RegNextWhen(mr1.io.data_req.data(2), update_leds) init(False)

    val codec_scl_addr = (mr1.io.data_req.addr === U"32'h00080010")
    val codec_sda_addr = (mr1.io.data_req.addr === U"32'h00080014")

    val write_codec_sda = mr1.io.data_req.valid && mr1.io.data_req.wr && codec_sda_addr
    val write_codec_scl = mr1.io.data_req.valid && mr1.io.data_req.wr && codec_scl_addr

    io.codec_sda.write := RegNextWhen(mr1.io.data_req.data(0), write_codec_sda) init(False)
    io.codec_scl.write := RegNextWhen(mr1.io.data_req.data(0), write_codec_scl) init(False)

    //============================================================
    // EOF
    //============================================================

    val eof_addr  = (mr1.io.data_req.addr === U"32'h00080040")
    val update_eof_sticky = mr1.io.data_req.valid && mr1.io.data_req.wr && eof_addr

    val eof_sticky = Reg(Bool) init(False)
    eof_sticky := io.eof ? True | (eof_sticky && !update_eof_sticky)

    //============================================================
    // Txt Buf RAM
    //============================================================

    val txt_buf_addr = (mr1.io.data_req.addr(15, 17 bits) === U"32'h00088000"(15, 17 bits))

    val update_txt_buf = mr1.io.data_req.valid && mr1.io.data_req.wr && txt_buf_addr

    io.txt_buf_wr       <> update_txt_buf
    io.txt_buf_wr_addr  <> mr1.io.data_req.addr(2, 11 bits)
    io.txt_buf_wr_data  <> mr1.io.data_req.data(0, 8 bits)

    reg_rd_data :=   (RegNext(eof_addr)      ? (B(0, 31 bits) ## eof_sticky) |
                     (RegNext(codec_sda_addr) ? (B(0, 31 bits) ## io.codec_sda.read) |
                     (RegNext(codec_scl_addr) ? (B(0, 31 bits) ## io.codec_scl.read) |
                                               B(0, 32 bits))))

}

