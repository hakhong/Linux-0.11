#!/bin/bash
# Start QEMU frozen at the reset vector with a gdb stub on localhost:1234.
# usage: qemu-debug.sh [main|boot] [extra qemu args]
#   main (default) : output/Image + output/hdc-0.11.img
#   boot           : 부트로더 디버깅. output/Image 가 있으면 그걸 쓴다 (setup 까지 따라가려면 필요).
#                    output/hdc-0.11.img 도 있으면 같이 붙여 continue 로 쉘까지 갈 수 있다.
#                    없으면 output/bootsect 단독 (bootsect 가 setup 을 못 읽어 setup 이전에서 멈춘다)
# -snapshot keeps the images untouched by whatever the code writes.
MODE=main
case "$1" in main|boot) MODE=$1; shift ;; esac

# 이전 디버그 세션의 QEMU가 남아 있으면 gdb가 이미 진행된 QEMU에 붙으므로 정리
pkill -f '^qemu-system-i386' 2>/dev/null && sleep 0.5

cd "$(dirname "$0")/../output" || exit 1

if [ "$MODE" = boot ]; then
  if [ -f Image ]; then
    FILES=(Image)
    ARGS=(-drive file=Image,format=raw,if=floppy -boot a -m 16M -snapshot)
    # 루트 파일시스템(dev 0301 = hd1). 없으면 continue 로 끝까지 가면 커널이
    # "Unable to mount root" 로 panic 한다 (부트로더 자체는 정상).
    if [ -f hdc-0.11.img ]; then
      ARGS+=(-drive file=hdc-0.11.img,format=raw,if=ide,index=0)
    else
      echo "warning: output/hdc-0.11.img 없음 -> 커널이 루트 마운트에서 panic 한다"
    fi
  else
    echo "warning: output/Image 없음 -> bootsect 단독 실행 (setup/보호모드 구간은 못 본다. ./build.sh 로 Image 를 만든다)"
    FILES=(bootsect)
    ARGS=(-drive file=bootsect,format=raw,if=floppy -boot a -snapshot)
  fi
else
  FILES=(Image hdc-0.11.img)
  ARGS=(-drive file=Image,format=raw,if=floppy
        -drive file=hdc-0.11.img,format=raw,if=ide,index=0
        -boot a -m 16M -snapshot)
fi

for f in "${FILES[@]}"; do
  [ -f "$f" ] || { echo "missing output/$f (run build.sh $MODE first)"; exit 1; }
done

qemu-system-i386 "${ARGS[@]}" -s -S "$@" &
QPID=$!
sleep 1
kill -0 $QPID 2>/dev/null || { echo "QEMU failed to start"; exit 1; }
echo "QEMU gdbstub ready"
wait $QPID
