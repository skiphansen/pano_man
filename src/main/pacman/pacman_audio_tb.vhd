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
-- version 001 initial release
--
use std.textio.ALL;
library ieee;
  use ieee.std_logic_1164.all;
  use ieee.std_logic_unsigned.all;
  use ieee.numeric_std.all;

-- use work.pkg_pacman.all;

entity PACMAN_TB is
end;

architecture Sim of PACMAN_TB is

  signal reset       : std_logic;
  signal clk         : std_logic;
  signal ena_6       : std_logic;
  signal hcnt        : std_logic_vector(8 downto 0) := "010000000"; -- 80
  signal vcnt        : std_logic_vector(8 downto 0) := "011111000"; -- 0F8
  signal do_hsync    : boolean;
  signal wr0_l       : std_logic := '1';    -- 0x5040 - 0x504F sound waveform: low 3 bits select one of 8 waveforms
  signal wr1_l       : std_logic := '1';    -- 0x5050 - 0x505F sound voice (frequency and volume)
  signal sound_on    : std_logic;
  signal sync_bus_db : std_logic_vector(7 downto 0);
  signal ab          : std_logic_vector(11 downto 0) := x"043";
  signal init_active : boolean := true;

  signal wr0         : std_logic := '1';    -- 0x5040 - 0x504F sound waveform: low 3 bits select one of 8 waveforms
  signal wr1         : std_logic := '1';    -- 0x5050 - 0x505F sound voice (frequency and volume)

  constant CLKPERIOD : time := 83.33 ns;

begin

  p_clk  : process
  begin
    clk <= '0';
    wait for CLKPERIOD / 2;
    clk <= '1';
    wait for CLKPERIOD - (CLKPERIOD / 2);
  end process;


  p_rst : process
  begin
    reset <= '1';
    wait for 100 ns;
    reset <= '0';
    wait;
  end process;

  p_clk_div : process
  begin
    wait until rising_edge(clk);
      if (ena_6 = '1') then
        ena_6 <= '0';
      else
        ena_6 <= '1';
      end if;
  end process;


  p_hvcnt : process
    variable hcarry,vcarry : boolean;
  begin
    wait until rising_edge(clk);
    if (ena_6 = '1') then
      hcarry := (hcnt = "111111111");
      if hcarry then
        hcnt <= "010000000"; -- 080
      else
        hcnt <= hcnt +"1";
      end if;
      -- hcnt 8 on circuit is 256H_L
      vcarry := (vcnt = "111111111");
      if do_hsync then
        if vcarry then
          vcnt <= "011111000"; -- 0F8
        else
          vcnt <= vcnt +"1";
        end if;
      end if;
    end if;
  end process;

  sound_on <= '1';

-- Voice 1 (7 bytes)
--   Waveform 5045h low 3 bits used – selects waveform 0-7 from ROM 
--   Frequency 5050h-5054h 20 bits in low nibbles 
--   Volume 5055h low nibble – 0 off to 15 loudest 
-- Voice 2 (6 bytes)
--   Waveform 504Ah low 3 bits used – selects waveform 0-7 from ROM
--   Frequency 5056h-5059h 16 bits in low nibbles 
--   Volume 505Ah low nibble – 0 off to 15 loudest 
--   
-- Voice 3 (6 bytes)
--   Waveform 504Fh low 3 bits used – selects waveform 0-7 from ROM 
--   Frequency 505Bh-505Eh 16 bits in low nibbles 
--   Volume 505Fh low nibble – 0 off to 15 loudest 
--
-- Lets set Voice 1 to 500 hz, voice 2 to 1 Khz and voice 3 to 2 Khz
-- V = 4095 * f / 375 or 500 hz = 0x1554, 1000 hz = 0x2aa8, 2000 hz = 5550

  p_reg_init : process(hcnt)
  begin
    if (hcnt(4 downto 2) = "000") then
    -- 0 - setup data
        case ab is
        -- waveforms
          when x"045" => sync_bus_db <= x"00"; wr0 <= '0';
          when x"04a" => sync_bus_db <= x"00"; wr0 <= '0';
          when x"04f" => sync_bus_db <= x"00"; wr0 <= '0';
       -- frequency voice 1
          when x"050" => sync_bus_db <= x"04"; wr1 <= '0';
          when x"051" => sync_bus_db <= x"05"; wr1 <= '0';
          when x"052" => sync_bus_db <= x"05"; wr1 <= '0';
          when x"053" => sync_bus_db <= x"01"; wr1 <= '0';
          when x"054" => sync_bus_db <= x"00"; wr1 <= '0';
       -- vol voice 1
          when x"055" => sync_bus_db <= x"0f"; wr1 <= '0';

       -- frequency voice 2
          when x"056" => sync_bus_db <= x"08"; wr1 <= '0';
          when x"057" => sync_bus_db <= x"0a"; wr1 <= '0';
          when x"058" => sync_bus_db <= x"0a"; wr1 <= '0';
          when x"059" => sync_bus_db <= x"02"; wr1 <= '0';
       -- vol voice 2
          when x"05a" => sync_bus_db <= x"0f"; wr1 <= '0';

       -- frequency voice 3
          when x"05b" => sync_bus_db <= x"00"; wr1 <= '0';
          when x"05c" => sync_bus_db <= x"05"; wr1 <= '0';
          when x"05d" => sync_bus_db <= x"05"; wr1 <= '0';
          when x"05e" => sync_bus_db <= x"05"; wr1 <= '0';
       -- vol voice 2
          when x"05f" => sync_bus_db <= x"0f"; wr1 <= '0';

          when others => null;
        end case;
    elsif (hcnt(4 downto 2) = "010") then
    -- 1 - write active
        wr0_l <= wr0;
        wr1_l <= wr1;
    elsif (hcnt(5 downto 2) = "100") then
    -- 2 - write inactive
        wr0_l <= '1';
        wr1_l <= '1';
        wr0 <= '1';
        wr1 <= '1';
    elsif (hcnt(4 downto 2) = "110") then
    -- 3 - advance address
        case ab is
          when x"045" => ab <= x"04a";
          when x"04a" => ab <= x"04f";
          when x"060" => null;
          when others => ab <= ab + '1';
        end case;
    end if;
  end process;


  u_audio : entity work.PACMAN_AUDIO
    port map (
      I_HCNT        => hcnt,
      --
      I_AB          => ab,
      I_DB          => sync_bus_db,
      --
      I_WR1_L       => wr1_l,
      I_WR0_L       => wr0_l,
      I_SOUND_ON    => sound_on,
      --
      O_AUDIO       => open,
      ENA_6         => ena_6,
      CLK           => clk
      );

end Sim;
