#!/bin/bash
# 2. Build the kernel in the container. Results go to output/:
#      Image, hdc-0.11.img                        - for 3_run.sh and VSCode F5
#      bootsect.elf, bootsect.lst, setup.lst, ... - for 4_debug_qemu.sh / 5_debug_gdb.sh
#    Starts the container first if it is not running (e.g. after a reboot).
#    컨테이너 안에서 커널을 빌드해 output/ 으로 복사한다. 컨테이너가 꺼져 있으면 먼저 띄운다.
cd "$(dirname "$0")" || exit 1
if [ -z "$(docker compose ps -q --status running linux011 2>/dev/null)" ]; then
  docker compose up -d || { echo "Cannot start the container. Run ./1_init.sh first."; exit 1; }
fi
# The original top-level Makefile does not descend into a directory whose
# archive already exists, so make each subdirectory first to pick up edits.
# boot/bootsect and boot/setup keep the 32-byte minix header for tools/build;
# output/ gets them without it, plus an ELF wrapper of bootsect for gdb.
docker compose exec linux011 sh -c "
  for d in kernel kernel/blk_drv kernel/chr_drv kernel/math mm fs lib; do make -C \$d || exit 1; done &&
  make && cp Image hdc-0.11.img /out/ &&
  dd if=boot/bootsect of=/out/bootsect bs=32 skip=1 2>/dev/null &&
  dd if=boot/setup of=/out/setup bs=32 skip=1 2>/dev/null &&
  cp boot/bootsect.s boot/setup.s boot/bootsect.lst boot/setup.lst /out/ &&
  objcopy -I binary -O elf32-i386 -B i386 /out/bootsect boot/bootsect_elf.o &&
  ld -m elf_i386 -Tdata 0x7c00 -e 0x7c00 -o /out/bootsect.elf boot/bootsect_elf.o
"
