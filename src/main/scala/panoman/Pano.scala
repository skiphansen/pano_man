package panoman

import spinal.core._
import spinal.lib.Counter
import spinal.lib.CounterFreeRun
import spinal.lib.GrayCounter
import spinal.lib.master
import spinal.lib.io.ReadableOpenDrain


case class Pano() extends Component {

    val io = new Bundle {
        val osc_clk             = in(Bool)

        val pano_button         = in(Bool)

        val vo_clk              = out(Bool)
        val vo                  = out(VgaData())

        val led_green           = in(Bool)
        val led_blue            = in(Bool)
        val led_red             = out(Bool)

        val vo_scl = in(Bool)
        val vo_sda = in(Bool)

        val audio_scl = master(ReadableOpenDrain(Bool))
        val audio_sda = master(ReadableOpenDrain(Bool))

        var audio_mclk = out(Bool)
        var audio_bclk = out(Bool)
        var audio_dacdat = out(Bool)
        var audio_daclrc = out(Bool)
        var audio_adcdat = in(Bool)
        var audio_adclrc = out(Bool)
    }

    noIoPrefix()

    //============================================================
    // Create pacman clock domain
    // We need 6.144 Mhz (1x), 12.288 (x2), and 24.576 (x4)
    // We'll multiple the 100 Mhz input clock by 8 and divide
    // by 5 to generated a 160 Mhz clock which we will feed into a
    // second DCM which will divide it by 6.5 to generate 24.615 Mhz.  
    // We'll divide 24.615 by 2 to generate 12.31 and by 4 to 
    // generate 6.15 Mhz which is .16 percent faster than ideal. 
    //============================================================

    val pacman_clk = new Pacman_clk()
    pacman_clk.io.CLKIN_IN <> io.osc_clk

    val pacman_clk1 = new Pacman_clk1()
    pacman_clk1.io.CLKIN_IN <> pacman_clk.io.CLKFX_OUT


    //============================================================
    // Create pacman clock domain
    //============================================================
    val pacmanClockDomain = ClockDomain(
        clock = pacman_clk1.io.CLKDV_OUT,
        frequency = FixedFrequency(24.576 MHz),
        config = ClockDomainConfig(
                    resetKind = BOOT
        )
    )

    val core = new ClockingArea(pacmanClockDomain) {
    // Create div2 and div4 clocks
        var clk_cntr6 = Reg(UInt(2 bits)) init(0)
        clk_cntr6 := clk_cntr6 + 1
        var clk12  = RegNext(clk_cntr6(0))
        var clk6  = RegNext(clk_cntr6(0) & ~clk_cntr6(1))

        val reset_unbuffered_ = True

        val reset_cntr = Reg(UInt(5 bits)) init(0)
        when(reset_cntr =/= U(reset_cntr.range -> true)){
            reset_cntr := reset_cntr + 1
            reset_unbuffered_ := False
        }

        val reset_ = RegNext(reset_unbuffered_)
        val u_pano_core = new PanoCore()
        io.audio_scl <> u_pano_core.io.codec_scl
        io.audio_sda <> u_pano_core.io.codec_sda
        io.led_red := u_pano_core.io.led1
    }

    var audio = new audio()
    audio.io.clk12 <> core.clk12
    audio.io.reset12_ := core.reset_
    audio.io.audio_mclk <> io.audio_mclk
    audio.io.audio_bclk <> io.audio_bclk
    audio.io.audio_dacdat <> io.audio_dacdat
    audio.io.audio_adcdat <> io.audio_adcdat
    audio.io.audio_daclrc <> io.audio_daclrc
    audio.io.audio_adclrc <> io.audio_adclrc

    var pacman = new Pacman()
    io.vo_clk <> pacman_clk.io.CLKFX_OUT
    pacman.io.clk <> pacman_clk1.io.CLKDV_OUT
    pacman.io.ena_12 <> core.clk12
    pacman.io.ena_6 <> core.clk6
    pacman.io.I_JOYSTICK_B := 31
    audio.io.audio_sample := pacman.io.O_AUDIO << 8

// I_SW bits:
// I_SW(3) Start 2
// I_SW(2) Coin 1
// I_SW(1) Coin 2
// I_SW(0) Start 1 - button

// Map pano button to Start 1
    pacman.io.I_SW := (0 -> io.pano_button, default->false)

// Atari 2600   Joystick  VGA        Pano
// Joystick     Signal    connector  Signal     
//---------     ------    ------     --------------------
// DB9.1        UP        J14.15     VGA SCL    
// DB9.2        DOWN      J14.12     VGA SDA    
// DB9.3        LEFT      J14.4      Blue LED (via added wire)
// DB9.4        RIGHT     J14.11     Green LED (via add wire)
// DB9.5        A Paddle  (n/c)         
// DB9.6        B Paddle  (n/c)         
// DB9.7        +5 V      J14.9                 
// DB9.8        Ground    J14.5         

// I_JOYSTICK_A bits:
//  4   Fire Joystick
//  3   RIGHT Joystick
//  2   LEFT Joystick
//  1   DOWN Joystick
//  0   UP Joystick

    pacman.io.I_JOYSTICK_A := (0 -> io.vo_scl, 
                               1 -> io.vo_sda, 
                               2 -> io.led_blue,
                               3 -> io.led_green,
                               4 -> false)

    pacman.io.I_RESET := ~core.reset_

    io.vo.vsync := !pacman.io.O_VSYNC
    io.vo.hsync := !pacman.io.O_HSYNC
    io.vo.blank_ := True
//    io.vo.blank_ := !pacman.io.O_BLANK


    io.vo.r := pacman.io.O_VIDEO_R << 4
    io.vo.g := pacman.io.O_VIDEO_G << 4
    io.vo.b := pacman.io.O_VIDEO_B << 4

}


