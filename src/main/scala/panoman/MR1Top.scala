
package mr1

import java.nio.file.{Files, Paths}
import spinal.core._
import spinal.lib.master
import spinal.lib.io.{ReadableOpenDrain, TriStateArray, TriState}

import panoman._

// Memory map
// A[0:31]     A31 A30 A15		
// 0x00000000 	0   0	0  On chip program RAM 
// 0x00008000 	0   0	1  On chip video text buffer RAM 
// 0x40000000   0   1	x  FPGA registers
// 0x80000000 	1   0	x  USB chip
// 0xc0000000 	1   1	x  SDRAM
class MR1Top(config: MR1Config ) extends Component {

    val io = new Bundle {
        val led1    = out(Bool)
        val led2    = out(Bool)
        val led3    = out(Bool)

        val switch_ = in(Bool)

        val codec_scl = master(ReadableOpenDrain(Bool))
        val codec_sda = master(ReadableOpenDrain(Bool))
        val vo_scl = master(ReadableOpenDrain(Bool))
        val vo_sda = master(ReadableOpenDrain(Bool))
        val gpio_out = out Bits(18 bits)

        val usb_a   = out(UInt(17 bits))
        val usb_d   = master(TriStateArray(16 bits))
        val usb_cs_ = out(Bool)
        val usb_rd_ = out(Bool)
        val usb_wr_ = out(Bool)

    }

    val mr1 = new MR1(config)

    val wmask = mr1.io.data_req.size.mux(

                    B"00"   -> B"0001",
                    B"01"   -> B"0011",
                    default -> B"1111") |<< mr1.io.data_req.addr(1 downto 0)

    mr1.io.instr_req.ready := True
    mr1.io.instr_rsp.valid := RegNext(mr1.io.instr_req.valid) init(False)

    val on_fpga_ram     = ~mr1.io.data_req.addr(31) && ~mr1.io.data_req.addr(30)
    val fpga_register   = ~mr1.io.data_req.addr(31) && mr1.io.data_req.addr(30)
    val usb_addr	= mr1.io.data_req.addr(31) && ~mr1.io.data_req.addr(30)
    val sdram_addr	= mr1.io.data_req.addr(31) && mr1.io.data_req.addr(30)

    val cpu_ram_rd_data = Bits(32 bits)
    val reg_rd_data     = Bits(32 bits)

    mr1.io.data_req.ready := True
    mr1.io.data_rsp.valid := RegNext(mr1.io.data_req.valid && !mr1.io.data_req.wr) init(False)
    mr1.io.data_rsp.data  := RegNext(on_fpga_ram) ? cpu_ram_rd_data | reg_rd_data

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
                enable  = mr1.io.data_req.valid && on_fpga_ram,
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
        cpu_ram.io.wren_b        := mr1.io.data_req.valid && mr1.io.data_req.wr && on_fpga_ram
        cpu_ram.io.byteena_b     := wmask
        cpu_ram.io.data_b        := mr1.io.data_req.data
        mr1.io.data_rsp.data     := cpu_ram.io.q_b
    }

    val update_leds = mr1.io.data_req.valid && mr1.io.data_req.wr && (mr1.io.data_req.addr === U"32'h00080000")

    io.led1 := RegNextWhen(mr1.io.data_req.data(0), update_leds) init(False)
    io.led2 := RegNextWhen(mr1.io.data_req.data(1), update_leds) init(False)
    io.led3 := RegNextWhen(mr1.io.data_req.data(2), update_leds) init(False)

 // I2C interfaces
    val codec_scl_addr = (mr1.io.data_req.addr === U"32'h40000010")
    val codec_sda_addr = (mr1.io.data_req.addr === U"32'h40000014")

    val write_codec_sda = mr1.io.data_req.valid && mr1.io.data_req.wr && codec_sda_addr
    val write_codec_scl = mr1.io.data_req.valid && mr1.io.data_req.wr && codec_scl_addr

    io.codec_sda.write := RegNextWhen(mr1.io.data_req.data(0), write_codec_sda) init(False)
    io.codec_scl.write := RegNextWhen(mr1.io.data_req.data(0), write_codec_scl) init(False)

    val vo_scl_addr = (mr1.io.data_req.addr === U"32'h40000018")
    val vo_sda_addr = (mr1.io.data_req.addr === U"32'h4000001c")


    val write_vo_sda = mr1.io.data_req.valid && mr1.io.data_req.wr && vo_sda_addr
    val write_vo_scl = mr1.io.data_req.valid && mr1.io.data_req.wr && vo_scl_addr

    io.vo_sda.write := RegNextWhen(mr1.io.data_req.data(0), write_vo_sda) init(False)
    io.vo_scl.write := RegNextWhen(mr1.io.data_req.data(0), write_vo_scl) init(False)

// GPIO interface
    val gpio_addr = (mr1.io.data_req.addr === U"32'h40000020")
    val write_gpio = mr1.io.data_req.valid && mr1.io.data_req.wr && gpio_addr

    io.gpio_out := RegNextWhen(mr1.io.data_req.data(0, 18 bits), write_gpio) init(0)

// USB interface 
    io.usb_cs_ := ~usb_addr
    io.usb_rd_ := (~io.usb_cs_ && ~mr1.io.data_req.wr) 
    io.usb_wr_ := ~(~io.usb_cs_ && mr1.io.data_req.valid && mr1.io.data_req.wr)
    io.usb_a := mr1.io.data_req.addr(18 downto 2)
    io.usb_d.writeEnable := (usb_addr && mr1.io.data_req.wr) ? B(1, 16 bits) | B(0, 16 bits)
    io.usb_d.write := mr1.io.data_req.data(15 downto 0)

    reg_rd_data :=   (RegNext(codec_sda_addr) ? (B(0, 31 bits) ## io.codec_sda.read) |
                     (RegNext(codec_scl_addr) ? (B(0, 31 bits) ## io.codec_scl.read) |
                     (RegNext(vo_sda_addr)    ? (B(0, 31 bits) ## io.vo_sda.read) |
                     (RegNext(vo_scl_addr)    ? (B(0, 31 bits) ## io.vo_scl.read) |
                     (RegNext(gpio_addr)      ? (B(0, 14 bits) ## io.gpio_out) |
                     (RegNext(usb_addr)       ? (B(0, 16 bits) ## io.usb_d.read) |
                      B(0, 32 bits)))))))

}

