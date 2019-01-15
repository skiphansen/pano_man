#!/bin/sh

#set -x

rom_path_src=../roms
rom_path=.
rom_md5_path=../roms.md5
romgen_path=../../../misc/romgen

build_them() {
   echo "Supported Pacman arcade ROMS verified (${romset} version)"
   rm ${rom_path_src}/main.bin 2> /dev/null
   for file in $main ; do
      cat ${rom_path_src}/${file} >> ${rom_path_src}/main.bin
   done

   rm ${rom_path_src}/gfx1.bin 2> /dev/null
   for file in $gfx1 ; do
      cat ${rom_path_src}/${file} >> ${rom_path_src}/gfx1.bin
   done

   # generate RTL code for small PROMS
   ${romgen_path}/romgen ${rom_path_src}/$prom1 PROM1_DST 9 l r e > ${rom_path}/prom1_dst.vhd 2> /dev/null
   ${romgen_path}/romgen ${rom_path_src}/$prom4 PROM4_DST 8 l r e > ${rom_path}/prom4_dst.vhd 2> /dev/null
   ${romgen_path}/romgen ${rom_path_src}/$prom7 PROM7_DST 4 l r e > ${rom_path}/prom7_dst.vhd 2> /dev/null

   # generate RAMB structures for larger ROMS
   ${romgen_path}/romgen ${rom_path_src}/gfx1.bin GFX1      13 l r e > ${rom_path}/gfx1.vhd 2> /dev/null
   ${romgen_path}/romgen ${rom_path_src}/main.bin ROM_PGM_0 14 l r e > ${rom_path}/rom0.vhd 2> /dev/null

   echo "Done"
}

if [ ! -e ${romgen_path}/romgen ]; then
   (cd ${romgen_path};make romgen)
fi

if [ ! -e ${romgen_path}/romgen ]; then
   echo "failed to build romgen utility"
   exit 1
fi

(cd ${rom_path_src};md5sum -c ${rom_md5_path}/puckmanb.md5) 2>/dev/null 1> /dev/null
if [ $? -eq 0 ]; then
   romset="puckmanb"
   main="namcopac.6e namcopac.6f namcopac.6h namcopac.6j"
   gfx1="pacman.5e pacman.5f"
   prom1="82s126.1m"
   prom4="82s126.4a"
   prom7="82s123.7f"
   build_them
   exit
fi

(cd ${rom_path_src};md5sum -c ${rom_md5_path}/puckman.md5) 2>/dev/null 1> /dev/null
if [ $? -eq 0 ]; then
   romset="puckman"
   main="pm1_prg1.6e pm1_prg2.6k pm1_prg3.6f pm1_prg4.6m pm1_prg5.6h pm1_prg6.6n pm1_prg7.6j pm1_prg8.6p"
   gfx1="pm1_chg1.5e pm1_chg2.5h pm1_chg3.5f pm1_chg4.5j"
   prom1="pm1-3.1m"
   prom4="pm1-4.4a"
   prom7="pm1-1.7f"
   build_them
   exit
fi

(cd ${rom_path_src};md5sum -c ${rom_md5_path}/pacman.md5) 2>/dev/null 1> /dev/null

if [ $? -eq 0 ]; then
   romset="pacman"
   main="pacman.6e pacman.6f pacman.6h pacman.6j"
   gfx1="pacman.5e pacman.5f"
   prom1="82s126.1m"
   prom4="82s126.4a"
   prom7="82s123.7f"
   build_them
   exit
fi

echo "No supported Pacman arcade ROMS found"

