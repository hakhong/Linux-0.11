#!/bin/bash
# 5. Boot loader debugging, terminal 2: attach gdb (with the d16 command) and stop at 0x7c00.
#    부트로더 디버깅 터미널 2: gdb 로 접속해 0x7c00 에서 멈춘다. 멈출 때마다 명령과 원본 소스 줄이 찍힌다.
cd "$(dirname "$0")" || exit 1
exec gdb -nx -q -x scripts/gdb-boot.gdb output/bootsect.elf
