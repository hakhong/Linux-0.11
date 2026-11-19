#!/bin/bash
# 4. Boot loader debugging, terminal 1: start QEMU halted, waiting for gdb on localhost:1234.
#    Then run ./5_debug_gdb.sh in a second terminal.
#    부트로더 디버깅 터미널 1: QEMU 를 멈춘 채로 띄우고 gdb 접속을 기다린다. 다른 터미널에서 5_debug_gdb.sh.
cd "$(dirname "$0")" || exit 1
exec bash scripts/qemu-debug.sh boot "$@"
