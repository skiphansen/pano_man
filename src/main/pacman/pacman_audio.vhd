--
-- A simulation model of Pacman hardware
-- Copyright (c) MikeJ - January 2006
--
-- All rights reserved
--
-- Redistribution and use in source and synthezised forms, with or without
-- modification, are permitted provided that the following conditions are met:
--
-- Redistributions of source code must retain the above copyright notice,
-- this list of conditions and the following disclaimer.
--
-- Redistributions in synthesized form must reproduce the above copyright
-- notice, this list of conditions and the following disclaimer in the
-- documentation and/or other materials provided with the distribution.
--
-- Neither the name of the author nor the names of other contributors may
-- be used to endorse or promote products derived from this software without
-- specific prior written permission.
--
-- THIS CODE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
-- AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
-- THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
-- PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE
-- LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
-- CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
-- SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
-- INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
-- CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
-- ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
-- POSSIBILITY OF SUCH DAMAGE.
--
-- You are responsible for any legal issues arising from your use of this code.
--
-- The latest version of this file can be found at: www.fpgaarcade.com
--
-- Email pacman@fpgaarcade.com
--
-- Revision list
--
-- version 003 Jan 2006 release, general tidy up
-- version 002 added volume multiplier
-- version 001 initial release
--
-- The following is from: https://www.walkofmind.com/programming/pie/wsg3.htm
-- Namco 3-channel Waveform Sound Generator
-- 
-- The sound chip used in Pacman is a 3-channel Waveform Sound Generator 
-- (WSG) custom-made by Namco. It allows up to three simultaneous voices each 
-- with independent control over its volume, frequency and waveform. All of 
-- the chip functions are controlled by the following 4-bit registers: 
-- 
--  Register     Description
--  00h-04h  Voice #1 frequency counter
--  05h  Voice #1 waveform (only 3 bits used)
--  06-09h   Voice #2 frequency counter
--  0Ah  Voice #2 waveform (only 3 bits used)
--  0Bh-0Eh  Voice #3 frequency counter
--  0Fh  Voice #3 waveform (only 3 bits used)
--  10h-14h  Voice #1 frequency
--  15h  Voice #1 volume
--  16h-19h  Voice #2 frequency
--  1Ah  Voice #2 volume
--  1Bh-1Eh  Voice #3 frequency
--  1Fh  Voice #3 volume
-- 
-- Frequencies and counters are 20-bit values stored with the least 
-- significant nibble first. Voice #2 and #3 are missing the register for the 
-- least significant nibble and it is assumed to be always zero. 
-- 
-- These registers are usually mapped into the memory space of the CPU. In 
-- the Pacman hardware the memory locations at 5040h-505Fh map the sound 
-- registers, so for example writing a value at the address 505Ah sets the 
-- volume of voice #2. 
-- 
-- Sound generation is based on a table that contains 8 different waveforms, 
-- where each waveform is described by 32 4-bit entries. For versatility and 
-- reuseability, this data is kept outside of the chip in a 256 byte PROM. 
-- 
-- The chip itself is clocked at 96 KHz, which is the main CPU clock (3.072 
-- MHz) divided by 32. At each cycle the frequency counter for each voice is 
-- incremented by the voice frequency, then the most significant 5 bits are 
-- used as an index to retrieve the current wave sample from the waveform 
-- table. The sample is then multiplied by the voice volume and sent to the 
-- amplifier for output. Note that a voice is actually muted if its volume or 
-- frequency is zero. 
-- 
-- Copyright (c) 1997-2004 Alessandro Scotti. All rights reserved.

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.std_logic_unsigned.all;
  use ieee.numeric_std.all;

library UNISIM;
  use UNISIM.Vcomponents.all;

-- use work.pkg_pacman.all;

entity PACMAN_AUDIO is
  port (
    I_HCNT            : in    std_logic_vector(8 downto 0);
    --
    I_AB              : in    std_logic_vector(11 downto 0);
    I_DB              : in    std_logic_vector( 7 downto 0);
    --
    I_WR1_L           : in    std_logic;    -- sound voice
    I_WR0_L           : in    std_logic;    -- sound waveform
    I_SOUND_ON        : in    std_logic;
    --
    O_AUDIO           : out   std_logic_vector(9 downto 0);
    ENA_6             : in    std_logic;
    CLK               : in    std_logic
    );
end;

architecture RTL of PACMAN_AUDIO is

  signal addr          : std_logic_vector(3 downto 0);
  signal data          : std_logic_vector(3 downto 0);
  signal vol_ram_wen   : std_logic;
  signal frq_ram_wen   : std_logic;
  signal vol_ram_dout  : std_logic_vector(3 downto 0);
  signal frq_ram_dout  : std_logic_vector(3 downto 0);

  signal sum           : std_logic_vector(5 downto 0);
  signal accum_reg     : std_logic_vector(5 downto 0);
  signal rom3m_n       : std_logic_vector(15 downto 0);
  signal rom3m_w       : std_logic_vector(3 downto 0);
  signal rom3m         : std_logic_vector(3 downto 0);

  signal rom1m_addr    : std_logic_vector(8 downto 0);
  signal rom1m_data    : std_logic_vector(7 downto 0);

  signal audio_vol_out : std_logic_vector(3 downto 0);
  signal audio_wav_out : std_logic_vector(3 downto 0);
  signal audio_mul_out : std_logic_vector(7 downto 0);
  signal audio_mix     : std_logic_vector(9 downto 0);
  signal audio_sum_out : std_logic_vector(9 downto 0);

begin

  -- 3L 74LS157 mux: 2H=0 use AB[3:0] else {32H...4H}
  -- 3K 74LS158 mux inverting: 2H=0 use DB[3:0] else accum_reg
  p_sel_com : process(I_HCNT, I_AB, I_DB, accum_reg)
  begin
    if (I_HCNT(1) = '0') then -- 2h,
      addr <= I_AB(3 downto 0);
      data <= I_DB(3 downto 0); -- removed invert JR: compensate for 16x4 RAMs being inverted on output
    else
      addr <= I_HCNT(5 downto 2);
      data <= accum_reg(4 downto 1);
    end if;
  end process;

  -- write enable for 2L vol_ram: write on clk_6MHz and WR1_L=0
  -- write enable for 2K freq_ram: write on clk_6MHz and rom3m=1? shouldn't this be active low?!?
  
  p_ram_comb : process(I_WR1_L, rom3m, ENA_6)
  begin
    vol_ram_wen <= '0';
    if (I_WR1_L = '0') and (ENA_6 = '1') then
      vol_ram_wen <= '1';
    end if;

    frq_ram_wen <= '0';
    if (rom3m(1) = '1') and (ENA_6 = '1') then
      frq_ram_wen <= '1';
    end if;
  end process;

  -- 2L 82S25 16x4 RAM inverting:  WE
  -- 2K 82S25 16x4 RAM inverting: 

  -- Xilinx RAMs, but look in pacman_video.vhd for an example of RTL code
  vol_ram : for i in 0 to 3 generate
  -- should be a latch, but we are using a clock
  begin
    inst: RAM16X1D
      port map (
        a0    => addr(0),
        a1    => addr(1),
        a2    => addr(2),
        a3    => addr(3),
        dpra0 => addr(0),
        dpra1 => addr(1),
        dpra2 => addr(2),
        dpra3 => addr(3),
        wclk  => CLK,
        we    => vol_ram_wen,
        d     => data(i),
        dpo   => vol_ram_dout(i)
        );
  end generate;

  frq_ram : for i in 0 to 3 generate
  -- should be a latch, but we are using a clock
  begin
    inst: RAM16X1D
      port map (
        a0    => addr(0),
        a1    => addr(1),
        a2    => addr(2),
        a3    => addr(3),
        dpra0 => addr(0),
        dpra1 => addr(1),
        dpra2 => addr(2),
        dpra3 => addr(3),
        wclk  => CLK,
        we    => frq_ram_wen,
        d     => data(i),
        dpo   => frq_ram_dout(i)
        );
  end generate;


  -- 3M 256x4 PROM from Schematic
  -- during wr0_l=0: write strobe on !H2 && H1 (during mux in of A/D bus)
  -- during wr0_l=1: clr,idle on !H2, followed by 5x (4x for voice 2 & 3) clk_dff, write strobe combo on H2, final clk out_dff at end
  
  
  p_control_rom_comb : process(I_HCNT)
  begin
    -- rom3m(0) - 1 - update accum_reg from sum
    -- rom3m(1) - 2 - frq_ram_wen
    -- rom3m(2) - 4 - update audio_vol_out & audio_wav_out
    -- rom3m(3) - 8 - clear accum

-- 64 states to update 3 voices
-- 8 0 1 2 0 0 1 2 0 0 1 2 0 0 1 2 0 0 1 2 0 0 0 4
-- 8 0 1 2 0 0 1 2 0 0 1 2 0 0 1 2 0 0 0 4
-- 8 0 1 2 0 0 1 2 0 0 1 2 0 0 1 2 0 0 0 4
--- clear, 
--      wait, do nibble, update nibble sum, wait  (0 1 2 0)
--      wait, do nibble, update nibble sum, wait  (0 1 2 0)
--      wait, do nibble, update nibble sum, wait  (0 1 2 0)
--      wait, do nibble, update nibble sum, wait  (0 1 2 0)
--      wait, wait, update output vol and wave    (0 0 4)


    rom3m_n <= x"0000"; rom3m_w <= x"0"; -- default assign
    case I_HCNT(3 downto 0) is
      when x"0" => rom3m_n <= x"0008"; rom3m_w <= x"0"; -- CPU write
      when x"1" => rom3m_n <= x"0000"; rom3m_w <= x"2"; -- update phase
      when x"2" => rom3m_n <= x"1111"; rom3m_w <= x"0"; -- frq_ram_wen
      when x"3" => rom3m_n <= x"2222"; rom3m_w <= x"0";
      when x"4" => rom3m_n <= x"0000"; rom3m_w <= x"0";
      when x"5" => rom3m_n <= x"0000"; rom3m_w <= x"2";
      when x"6" => rom3m_n <= x"1101"; rom3m_w <= x"0"; -- frq_ram_wen
      when x"7" => rom3m_n <= x"2242"; rom3m_w <= x"0";
      when x"8" => rom3m_n <= x"0080"; rom3m_w <= x"0";
      when x"9" => rom3m_n <= x"0000"; rom3m_w <= x"2";
      when x"A" => rom3m_n <= x"1011"; rom3m_w <= x"0"; -- frq_ram_wen
      when x"B" => rom3m_n <= x"2422"; rom3m_w <= x"0";
      when x"C" => rom3m_n <= x"0800"; rom3m_w <= x"0";
      when x"D" => rom3m_n <= x"0000"; rom3m_w <= x"2";
      when x"E" => rom3m_n <= x"0111"; rom3m_w <= x"0"; -- frq_ram_wen
      when x"F" => rom3m_n <= x"4222"; rom3m_w <= x"0";
      when others => null;
    end case;
  end process;

  p_control_rom_op_comb : process(I_HCNT, I_WR0_L, rom3m_n, rom3m_w)
  begin
    rom3m <= rom3m_w;
    if (I_WR0_L = '1') then
      case I_HCNT(5 downto 4) is
        when "00" => rom3m <= rom3m_n( 3 downto 0);
        when "01" => rom3m <= rom3m_n( 7 downto 4);
        when "10" => rom3m <= rom3m_n(11 downto 8);
        when "11" => rom3m <= rom3m_n(15 downto 12);
        when others => null;
      end case;
    end if;
  end process;

  p_adder : process(vol_ram_dout, frq_ram_dout, accum_reg)
  begin
    -- 1K 4 bit adder
    sum <= ('0' & vol_ram_dout & '1') + ('0' & frq_ram_dout & accum_reg(5));
  end process;

  p_accum_reg : process
  begin
    -- 1L
    wait until rising_edge(CLK);
    if (ENA_6 = '1') then
      if (rom3m(3) = '1') then -- clear
        accum_reg <= "000000";
      elsif (rom3m(0) = '1') then -- rising edge clk
        accum_reg <= sum(5 downto 1) & accum_reg(4);
      end if;
    end if;
  end process;

  p_rom_1m_addr_comb : process(accum_reg, frq_ram_dout)
  begin
    rom1m_addr(8) <= '0';
    rom1m_addr(7 downto 5) <= frq_ram_dout(2 downto 0);
    rom1m_addr(4 downto 0) <= accum_reg(4 downto 0);

  end process;

  audio_rom_1m : entity work.PROM1_DST
    port map(
      CLK         => CLK,
      ENA         => ENA_6,  
      ADDR        => rom1m_addr,
      DATA        => rom1m_data
      );

  p_original_output_reg : process
  begin
    -- 2m used to use async clear
    wait until rising_edge(CLK);
    if (ENA_6 = '1') then
      if (I_SOUND_ON = '0') then
        audio_vol_out <= "0000";
        audio_wav_out <= "0000";
      elsif (rom3m(2) = '1') then
        audio_vol_out <= vol_ram_dout(3 downto 0);
        audio_wav_out <= rom1m_data(3 downto 0);
      end if;
    end if;
  end process;

  u_volume_mul : entity work.PACMAN_MUL4 -- replaces external fet switch used for volume
    port map(
      A             => audio_vol_out,
      B             => audio_wav_out,
      R             => audio_mul_out
      );

--  p_output_reg : process
--  begin
--    wait until rising_edge(CLK);
--    if (ENA_6 = '1') then
--      O_AUDIO(7 downto 0) <= audio_mul_out;
--    end if;
--  end process;

  p_audio_mix : process
  begin
    -- 2m used to use async clear
    wait until rising_edge(CLK);
    if (ENA_6 = '1') then
      if (I_HCNT(5 downto 0) = 32) then audio_sum_out(9 downto 0) <= "00" & audio_mul_out;
		elsif (I_HCNT(5 downto 0) = 52) then audio_sum_out(9 downto 0) <= audio_sum_out + ("00" & audio_mul_out);
		elsif (I_HCNT(5 downto 0) = 8)  then audio_sum_out(9 downto 0) <= audio_sum_out + ("00" & audio_mul_out);
      end if;
      if (I_HCNT(5 downto 0) = 10) then O_AUDIO(9 downto 0) <= audio_sum_out;
      end if;
    end if;
  end process;

end architecture RTL;
