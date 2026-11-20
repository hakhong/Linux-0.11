set architecture i8086
set pagination off
source scripts/d16.py
# 멈출 때마다 현재 명령 1개 출력. d16 이 CR0.PE 를 보고 16/32비트를 알아서 고른다.
define hook-stop
  d16 1
end
source scripts/boot-help.gdb
bhelp
target remote localhost:1234
hbreak *0x7c00
continue
