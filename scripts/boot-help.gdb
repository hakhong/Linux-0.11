# 명령어/주소 안내. 터미널 gdb(gdb-boot.gdb)와 VSCode bootsect 설정(launch.json)이 같이 쓴다.
# gdb 안에서 `bhelp` 로 언제든 다시 볼 수 있다 (VSCode Debug Console 에서는 -exec bhelp).
define bhelp
  echo \n== commands (VSCode Debug Console: put -exec in front, e.g. -exec si) ==\n
  echo si / ni            run one instruction (ni steps over call)\n
  echo continue (c)       run to next breakpoint, or to the shell\n
  echo hbreak *0x9006c    breakpoint at a linear address\n
  echo info breakpoints   list breakpoints (delete N removes one)\n
  echo d16 10             next 10 instructions with source lines\n
  echo d16 1              current instruction (terminal prints it at every stop)\n
  echo info registers     all registers (p/x $ax for one)\n
  echo bhelp              show this list again\n
  echo \n== key addresses (hbreak *ADDR; full table in README) ==\n
  echo 0x7c00   bootsect start        0x90018  go: (bootsect moved to 0x90000)\n
  echo 0x9006c  call kill_motor (kernel loaded)   0x90093  jmpi 0,SETUPSEG\n
  echo 0x90200  setup start           0x90301  lmsw ax (enter protected mode)\n
  echo 0x90304  jmpi 0,8              0x0      startup_32 (head.s)\n
  echo main / sys_setup / printk / panic   by name after protected mode\n\n
end
