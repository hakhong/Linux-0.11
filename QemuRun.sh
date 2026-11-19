qemu-system-i386 \
  -drive file=output/Image,format=raw,if=floppy \
  -drive file=output/hdc-0.11.img,format=raw,if=ide,index=0 \
  -boot a \
  -m 16M
