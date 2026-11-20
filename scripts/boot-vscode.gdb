# VSCode bootsect 설정 전용. cppdbg 는 postRemoteConnectCommands 의 출력을 Debug Console 에
# 보여 주지 않고 멈출 때의 출력만 보여 준다. 그래서 멈출 때마다 여기서 출력한다.
#   - 첫 정지: 명령어/주소 안내(bhelp) 한 번
#   - 매 정지: 현재 명령 + 원본 소스 줄(d16 1), 레지스터(regs, 모드에 따라 16/32비트). 터미널의 hook-stop 과 같다.
set $bhelp_done = 0
define hook-stop
  if $bhelp_done == 0
    set $bhelp_done = 1
    bhelp
  end
  d16 1
  regs
end
