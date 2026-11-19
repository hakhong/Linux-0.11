#!/bin/bash
# usage: ./build.sh [main|boot|up|clean]
#   main (default) : 전체 빌드 -> output/Image, output/hdc-0.11.img
#   boot           : bootsect만 빌드 -> output/bootsect (+ gdb용 output/bootsect.elf)
#   up             : 컨테이너 (재)생성
#   clean          : make clean
cd "$(dirname "$0")" || exit 1
case "${1:-main}" in
  main)
    # The top Makefile (as in the original) does not descend into a directory
    # whose archive already exists, so make each one first to pick up edits.
    docker compose exec linux011 sh -c "
    for d in kernel kernel/blk_drv kernel/chr_drv kernel/math mm fs lib; do make -C \$d || exit 1; done && \
    make && cp Image /out/ && cp hdc-0.11.img /out/
  "
    ;;
  boot)
    # boot/bootsect, boot/setup keep the 32-byte minix header for tools/build; strip it for output/
      docker compose exec linux011 sh -c "
    make boot/bootsect boot/setup && \
    dd if=boot/bootsect of=/out/bootsect bs=32 skip=1 2>/dev/null && \
    dd if=boot/setup of=/out/setup bs=32 skip=1 2>/dev/null && \
    cp boot/bootsect.s boot/setup.s boot/bootsect.lst boot/setup.lst /out/ && \
    objcopy -I binary -O elf32-i386 -B i386 /out/bootsect boot/bootsect_elf.o && \
    ld -m elf_i386 -Tdata 0x7c00 -e 0x7c00 -o /out/bootsect.elf boot/bootsect_elf.o
  "
    ;;
  up)
    docker compose build --no-cache && docker compose up -d
    ;;
  clean)
    docker compose exec linux011 make clean
    ;;
  *)
    echo "usage: $0 [main|boot|up|clean]"
    exit 1
    ;;
esac
