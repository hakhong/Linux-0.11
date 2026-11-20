set architecture i8086
set pagination off
source scripts/d16.py
# 멈출 때마다 현재 명령 1개 출력. d16 이 CR0.PE 를 보고 16/32비트를 알아서 고른다.
define hook-stop
  d16 1
end
echo \n== commands ==\n
echo si / ni            run one instruction (ni steps over call)\n
echo continue (c)       run to next breakpoint, or to the shell\n
echo hbreak *0x9006c    breakpoint at a linear address\n
echo info breakpoints   list breakpoints (delete N removes one)\n
echo d16 10             next 10 instructions with source lines\n
echo x/10i $cs*16+$pc   raw disassembly at the real address\n
echo info registers     all registers (p/x $ax for one)\n
echo layout regs        register window (TUI)\n
echo quit               leave gdb\n
echo \n== key addresses (hbreak *ADDR; full table in README) ==\n
echo 0x7c00   bootsect start        0x90018  go: (bootsect moved to 0x90000)\n
echo 0x9006c  call kill_motor (kernel loaded)   0x90093  jmpi 0,SETUPSEG\n
echo 0x90200  setup start           0x90301  lmsw ax (enter protected mode)\n
echo 0x90304  jmpi 0,8              0x0      startup_32 (head.s)\n
echo main / sys_setup / printk / panic   by name after protected mode\n\n
target remote localhost:1234
hbreak *0x7c00
continue
