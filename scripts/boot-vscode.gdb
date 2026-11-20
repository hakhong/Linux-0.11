# VSCode bootsect 설정 전용. cppdbg 는 postRemoteConnectCommands 의 출력을 Debug Console 에
# 보여 주지 않고 멈출 때의 출력만 보여 준다. 그래서 첫 정지(0x7c00)에서 한 번만 bhelp 를 찍는다.
set $bhelp_done = 0
define hook-stop
  if $bhelp_done == 0
    set $bhelp_done = 1
    bhelp
  end
end
