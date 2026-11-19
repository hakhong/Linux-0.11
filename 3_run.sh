#!/bin/bash
# 3. Boot output/Image (floppy) + output/hdc-0.11.img (hard disk, root fs) with QEMU in WSL.
#    QEMU 로 부팅한다. 창은 WSLg 로 Windows 에 뜬다.
cd "$(dirname "$0")" || exit 1
qemu-system-i386 \
  -drive file=output/Image,format=raw,if=floppy \
  -drive file=output/hdc-0.11.img,format=raw,if=ide,index=0 \
  -boot a \
  -m 16M
