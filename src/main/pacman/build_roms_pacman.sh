#!/bin/sh

#set -x

# SHA1 sums of files required
# 8d0268dee78e47c712202b0ec4f1f51109b1f2a5 *82s123.7f
# bbcec0570aeceb582ff8238a4bc8546a23430081 *82s126.1m
# 0c4d0bee858b97632411c440bea6948a74759746 *82s126.3m
# 19097b5f60d1030f8b82d9f1d3a241f93e5c75d6 *82s126.4a
# 87117ba5082cd7a615b4ec7c02dd819003fbd669 *namcopac.6e
# 326dbbf94c6fa2e96613dedb53702f8832b47d59 *namcopac.6f
# 7e1945f6eb51f2e51806d0439f975f7a2889b9b8 *namcopac.6h
# 01b4c38108d9dc4e48da4f8d685248e1e6821377 *namcopac.6j
# 06ef227747a440831c9a3a613b76693d52a2f0a9 *pacman.5e
# 4a937ac02216ea8c96477d4a15522070507fb599 *pacman.5f

rom_path_src=../roms
rom_path=.
romgen_path=../../../misc/romgen

if [ ! -e ${romgen_path}/romgen ]; then
   (cd ${romgen_path};make romgen)
fi

if [ ! -e ${romgen_path}/romgen ]; then
   echo "failed to build romgen utility"
   exit 1
fi

(cd ${rom_path_src};md5sum -c pacman_roms.md5) 2>&1 > /dev/null

if [ $? -eq 0 ]; then
   echo "Correct Pacman arcade ROMS verified"
else
   echo "Warning: ROM images do not match the Pacman arcade ROMS"
fi

# concatenate consecutive ROM regions
cat ${rom_path_src}/*.5e ${rom_path_src}/*.5f > ${rom_path_src}/gfx1.bin
cat ${rom_path_src}/*.6e ${rom_path_src}/*.6f ${rom_path_src}/*.6h ${rom_path_src}/*.6j > ${rom_path_src}/main.bin

# generate RTL code for small PROMS
${romgen_path}/romgen ${rom_path_src}/*.1m     PROM1_DST  9 l r e     > ${rom_path}/prom1_dst.vhd
${romgen_path}/romgen ${rom_path_src}/*.4a     PROM4_DST  8 l r e     > ${rom_path}/prom4_dst.vhd
${romgen_path}/romgen ${rom_path_src}/*.7f     PROM7_DST  4 l r e     > ${rom_path}/prom7_dst.vhd

# generate RAMB structures for larger ROMS
${romgen_path}/romgen ${rom_path_src}/gfx1.bin GFX1      13 l r e > ${rom_path}/gfx1.vhd
${romgen_path}/romgen ${rom_path_src}/main.bin ROM_PGM_0 14 l r e > ${rom_path}/rom0.vhd


echo done
