# Linux 0.11 (WSL + Docker + QEMU)

[English](README.md) | **한국어**

Linus Torvalds의 Linux 0.11(1991) 원본 소스를 **WSL 안의 Docker 컨테이너에서 빌드**하고, **WSL의 QEMU로 부팅**하면서 **gdb로 전원 ON부터 쉘까지 한 줄씩 따라가는** 학습용 저장소다.

- 커널 소스는 원본에 **gcc 4.8 빌드와 QEMU 부팅에 꼭 필요한 것만** 고쳤다. `bootsect.s`, `setup.s`, `tools/build.c`, 커널 `.s` 파일은 원본 그대로다. 원본은 kernel.org의 [linux-0.11.tar.gz](https://www.kernel.org/pub/linux/kernel/Historic/linux-0.11.tar.gz)이다.
- 부트로더(16비트 리얼모드)는 터미널의 gdb로, `startup_32` 이후(32비트 보호모드)는 VSCode의 F5로 디버깅한다.
- 부팅 과정 해설: [docs/boot-guide.html](docs/boot-guide.html) (영어: [docs/boot-guide.en.html](docs/boot-guide.en.html)). 저장소를 받은 뒤 브라우저로 연다.

## 구성

| 위치 | 내용 |
|---|---|
| `boot/`, `fs/`, `include/`, `init/`, `kernel/`, `lib/`, `mm/`, `tools/build.c`, `Makefile` | 커널 소스 (원본 + 최소 패치) |
| `hdc-0.11.img` | 루트 파일시스템 하드디스크 이미지 (`/bin/sh`, `gcc` 등이 들어 있음) |
| `Dockerfile`, `docker-compose.yml` | 빌드 환경 (Ubuntu 14.04, gcc 4.8, bin86) |
| `1_init.sh` ~ `5_debug_gdb.sh`, `9_clean.sh` | 실행하는 스크립트. 번호가 순서다 ([처음부터 실행하는 순서](#처음부터-실행하는-순서)) |
| `scripts/` | 번호 스크립트와 VSCode가 쓰는 것: gdbstub을 켠 QEMU, gdb 설정, `d16` 명령 |
| `.vscode/` | VSCode 빌드 작업, F5 디버깅 설정, 추천 확장 |
| `docs/` | 부팅 해설 (한국어, 영어) |

## 개발 환경

Windows의 WSL2 하나에 모두 들어 있다. Docker Desktop은 쓰지 않고 **WSL 안에 설치한 Docker Engine**을 쓴다.

```
Windows ── VSCode ──(WSL 확장)──> WSL2 (Ubuntu 24.04)
                                   ├─ Docker Engine ── 컨테이너 linux-0.11 (Ubuntu 14.04, gcc 4.8, bin86)
                                   │                     └ 저장소를 /build로 마운트해서 빌드, 결과는 output/
                                   ├─ QEMU (qemu-system-i386) ── output/Image + output/hdc-0.11.img 부팅
                                   └─ gdb + python3 (scripts/d16.py) ── QEMU gdbstub(localhost:1234)에 접속
```

| 도구 | 확인한 버전 | 설치 (WSL) |
|---|---|---|
| Docker Engine, Docker Compose | 29.9, v5.6 | Docker 공식 문서의 Ubuntu용 Docker Engine 설치 방법 |
| QEMU | 8.2.2 | `sudo apt install qemu-system-x86` |
| gdb | 15.1 | `sudo apt install gdb` (python 지원 포함) |
| python3, objdump | 3.12, binutils 2.42 | `sudo apt install python3 binutils` (`d16`이 16비트 디스어셈블에 objdump를 쓴다) |
| 컨테이너 안 | gcc 4.8.4, make, bin86(as86/ld86) | `Dockerfile`이 설치 |

QEMU 창은 WSLg로 Windows에 뜬다.

**왜 Ubuntu 14.04인가:** 원본을 가장 덜 고치고 빌드되는 컴파일러가 gcc 4.8이다. 14.04는 지원이 끝났고 패키지 저장소가 느려서(이미지 빌드에 15분 이상), 저장소가 사라지면 이미지를 다시 만들 수 없게 된다. Ubuntu 24.04(gcc 13)도 시험했다. `-fgnu89-inline -fno-pie -fcf-protection=none` 등을 더하고 `console.c`의 `attr`이 지워지지 않게 하면 빌드는 되지만, 부팅 후 `/etc/rc` 다음에 `Kernel panic: free_page_tables called with wrong alignment`로 멈춘다. gcc 13의 최적화가 1991년 코드의 가정을 더 깨는 것으로 보여 원본을 더 고쳐야 하므로, 지금은 14.04를 쓴다.

### VSCode 확장

저장소를 열면 `.vscode/extensions.json`이 아래 확장을 추천한다.

| 확장 | 어디에 설치 | 용도 |
|---|---|---|
| WSL (`ms-vscode-remote.remote-wsl`, Remote Development 팩에 포함) | Windows | 폴더를 **"WSL: Open Folder in WSL"** 로 연다 |
| C/C++ (`ms-vscode.cpptools`) | WSL | F5 디버깅(`cppdbg` → gdb), 코드 탐색 |
| Container Tools (`ms-azuretools.vscode-containers`) | WSL | 컨테이너 확인 (선택) |

C/C++ 확장은 **WSL 쪽**에 설치되어야 한다. WSL에서 폴더를 연 뒤 확장 화면에서 "Install in WSL"을 누른다.

## 처음부터 실행하는 순서

번호가 붙은 스크립트를 순서대로, WSL 터미널에서 저장소 루트에서 실행한다.

| 스크립트 | 하는 일 | 언제 |
|---|---|---|
| `./1_init.sh` | Docker 이미지(Ubuntu 14.04, gcc 4.8, bin86)를 만들고 빌드 컨테이너 `linux-0.11`을 띄운다 (`docker compose build --no-cache && docker compose up -d`) | 처음 한 번. 15분 이상 걸린다 (Ubuntu 14.04 패키지 저장소가 느림) |
| `./2_build.sh` | 컨테이너 안에서 커널을 빌드하고 결과를 `output/`으로 복사한다: `Image`, `hdc-0.11.img`, 부트 디버깅용 `bootsect.elf`, `*.lst`. 재부팅 등으로 컨테이너가 꺼져 있으면 먼저 띄운다 | 소스를 고칠 때마다 |
| `./3_run.sh` | WSL의 QEMU로 부팅한다. 창은 WSLg로 Windows에 뜬다 | 실행해 볼 때 |
| `./4_debug_qemu.sh` | 부트로더 디버깅 터미널 1: QEMU를 멈춘 채로 띄우고 gdb를 기다린다 | 부트로더를 디버깅할 때 |
| `./5_debug_gdb.sh` | 부트로더 디버깅 터미널 2: gdb로 접속, 0x7c00에서 멈춘다 | 4와 함께 |
| `./9_clean.sh` | 컨테이너 안에서 `make clean` | 필요할 때 |

clone부터 쉘 프롬프트까지:

```bash
# 도구 설치 (개발 환경 참고). docker 그룹에 넣은 뒤에는 터미널을 새로 연다
sudo apt install qemu-system-x86 gdb python3 binutils
sudo usermod -aG docker $USER

git clone https://github.com/hakhong/Linux-0.11.git
cd Linux-0.11
./1_init.sh        # 처음 한 번
./2_build.sh
./3_run.sh
```

`2_build.sh`는 하위 디렉터리를 먼저 `make` 한다. 원본 최상위 Makefile은 하위 디렉터리 결과물(`fs/fs.o` 등)이 이미 있으면 다시 들어가지 않기 때문이다.

부팅하면 `[/usr/root]#` 프롬프트가 뜬다. 쉘 안에서 `gcc -o hello hello.c && ./hello`도 된다. 이 디스크 이미지에는 예전 판의 실습용 프로그램 `iam`, `whoami`도 들어 있는데, 원본 커널에는 그 시스템 콜이 없어서 실행되지 않는다.

## 원본과 다른 점

원본은 1991년 **gcc 1.x와 a.out**용이고, 빌드 환경에는 **gcc 4.8**이 있다. 최적화를 위해서가 아니라, 지금 컴파일러가 거부하거나 다르게 동작하는 곳만 원본을 가장 덜 바꾸는 방법으로 고쳤다. 고친 파일은 26개다. 소스에는 실제로 고친 코드만 있고, 무엇을 언제 왜 고쳤는지는 아래 표와 커밋 이력에 남겼다. 커밋 `Linux 0.11 원본 소스로 교체` 다음 커밋이 패치 전체다.

| 분류 | 파일 | 바꾼 것 | 이유 |
|---|---|---|---|
| 빌드 도구 | `Makefile`, 하위 `Makefile` 7개 | `gas`/`gld`/`gar` → `as --32`/`ld -m elf_i386`/`ar`. gcc에 `-m32 -g -fleading-underscore -fno-builtin -fno-stack-protector` 추가, gcc 1.x 전용 옵션(`-fcombine-regs`, `-mstring-insns`) 삭제 | 지금 도구는 32비트 ELF를 만든다. `-fleading-underscore`로 C 심볼에도 a.out 시절처럼 `_`가 붙어서 원본 `.s` 파일(`_main`, `_schedule` 등)을 그대로 쓸 수 있다 |
| Image 만들기 | `Makefile` | `tools/build`를 `-m32`로, `MAJOR`/`MINOR`를 `major`/`minor`에 연결해 컴파일. `ROOT_DEV=/dev/hd1`이고 컨테이너에 없으면 `mknod`로 만든다. ELF인 `tools/system` 대신 앞에 0 1024바이트를 붙인 `tools/kernel`을 넘긴다. as86 리스팅(`-l`), `System.map`은 `nm`으로 | 원본 `build.c`를 한 줄도 안 고치고 쓰기 위해서다 (32비트 호스트, a.out 헤더, 장치 파일을 가정함) |
| 키보드 규칙 | `kernel/chr_drv/Makefile` | `keyboard.S` → (cpp) → `keyboard.s` 중간 파일 없이 `cpp \| as`로 바로 `keyboard.o` | Windows 드라이브(`/mnt/d`)는 대소문자를 구분하지 않는다. `keyboard.s`가 곧 `keyboard.S`라서 원본 규칙대로면 `make clean`이 소스를 지운다 |
| 인라인 asm | `string.h`, `asm/memory.h`, `linux/sched.h`, `mm/memory.c`, `fs/bitmap.c`, `fs/buffer.c`, `fs/namei.c`, `chr_drv/console.c`, `blk_drv/hd.c`, `blk_drv/floppy.c` | 입력으로 준 레지스터를 clobber 목록에도 적은 asm을, 그 레지스터를 더미 출력 변수(`d0`, `d1` …)에 묶는 형태로. 출력이 새로 생긴 asm에는 `__volatile__`, 메모리를 쓰는 asm에는 `"memory"` | gcc 3 이후로는 `impossible constraints` 에러다. 그냥 clobber에서 빼면 gcc가 바뀐 레지스터 값을 그대로 다시 쓴다. asm 본문은 그대로이고 피연산자 번호가 밀린 `%N`만 맞췄다 |
| 바이트 레지스터 | `asm/segment.h` | `get_fs_byte`/`put_fs_byte`의 `"r"` → `"q"` | `"r"`이면 gcc가 `%esi`를 골라 32비트에 없는 `%sil`을 만든다 |
| 방향 플래그 | `boot/head.s`, `mm/memory.c`, `string.h`(memmove), `chr_drv/console.c`(scrdown) | `std`를 쓴 asm 끝에 `cld` | gcc 4.8은 "DF=0"을 가정하고 구조체 복사를 `rep movsl`로 만든다. 안 고치면 `get_free_page()` 직후의 fork 구조체 복사가 거꾸로 되어 task 1(init)이 실행되지 않는다 |
| 옛 문법 | `lib/malloc.c`, `fs/exec.c`, `blk_drv/blk.h`, `chr_drv/keyboard.S`, `boot/head.s`, `init/main.c` | 캐스트에 대입 → 괄호 대입, `#elif` → `#else`, `xorl %al,%al` → `xorl %eax,%eax`, `.align 3` → `.align 8`, main.c의 `fork`/`pause`/`sync` 정의에서 `static` 제거 | gcc 1.x, 옛 gas는 받아 줬지만 지금은 에러다. `.align n`은 a.out에선 2ⁿ바이트, ELF에선 n바이트. fork/pause가 main 안에 인라인되는 것은 확인함 |
| QEMU | `blk_drv/hd.c` | `controller_ready()`가 BUSY 비트만 확인, 부팅 시 컨트롤러 리셋 생략(`reset = 0`) | SeaBIOS가 IDE 장치 선택을 (없는) 슬레이브에 남겨 둬서 상태가 0x00이고, QEMU는 원본의 소프트 리셋 뒤 READY를 세우지 않는다. 그대로면 `HD controller not ready`로 panic |
| 키보드 배열 | `include/linux/config.h` | `KBD_FINNISH` → `KBD_US` | 원본 기본값은 핀란드식이라 한국/US 키보드로 치면 `/`가 `-`, `-`가 `+`, `>`가 `:`로 들어간다. 원본에 있는 배열 중 하나를 고른 것이고 커널 크기는 같다 |

- 커널은 약 107KB다. 원본 Makefile대로 `-O`를 쓴다. `-O`는 `main()`의 `fork()`/`pause()`를 인라인해서, fork 뒤 task 0이 스택을 쓰지 않게 하는 데도 필요하다. 그래서 gdb에서 일부 변수가 `<optimized out>`으로 보일 수 있다.
- 빌드 경고(`volatile void`, 괄호 권장 등)는 1991년 코드라서 나오는 것이고 동작과 무관하다.

## 디버깅

### main (VSCode)
F5 → `Linux 0.11 - main (QEMU + gdb)`. 빌드한 뒤 QEMU를 띄우고, `startup_32`(0x0)에서 먼저 멈춘다. 한 번 더 F5를 누르면 `main`에서 멈춘다. 이후 F10/F11을 쓸 수 있다.

### 부트로더 (터미널 2개)
VSCode(cppdbg)는 bootsect 구간에서 정지 상태를 "실행 중"으로 인식해 stepi가 안 된다. 그래서 WSL 터미널 2개로 직접 디버깅한다. 둘 다 저장소 루트에서 실행한다.

1. 빌드 (처음 한 번 또는 소스 수정 후): `./2_build.sh`. `output/bootsect.elf`와 리스팅 `output/bootsect.lst`, `output/setup.lst`도 함께 만든다.
2. 터미널 1: `./4_debug_qemu.sh`. QEMU가 gdb를 기다린다 (`QEMU gdbstub ready`가 나오면 준비 완료). `output/Image`로 부팅하고 `output/hdc-0.11.img`도 붙여서 `continue`로 쉘까지 갈 수 있다.
3. 터미널 2: `./5_debug_gdb.sh`. gdb가 0x7c00(BIOS가 부트섹터를 올려 실행하는 주소)에서 멈춘다.

#### 창 구성

| 창 | 띄우는 것 | 역할 |
|---|---|---|
| 터미널 1 | `4_debug_qemu.sh` | QEMU를 멈춘 상태로 켜고 gdb 접속을 기다림 |
| QEMU 화면 | 터미널 1이 자동으로 띄움 | 부팅 화면 (`Loading system ...`, 커널 메시지, 쉘) |
| 터미널 2 | `5_debug_gdb.sh` | gdb. 여기서 `si`, `continue` 등을 입력 |

`gdb -tui`를 따로 띄울 필요는 없다. `5_debug_gdb.sh`가 실행하는 `scripts/gdb-boot.gdb`의 내용은 이렇다.
```
set architecture i8086
source scripts/d16.py
define hook-stop      # 멈출 때마다 d16 1 실행
  d16 1
end
target remote localhost:1234
hbreak *0x7c00
continue
```

#### 어디까지 실행됐는지 보기
`si`든 `continue`든 멈출 때마다 `hook-stop`이 지금 멈춘 명령과 원본 소스 줄을 찍는다.
```
(gdb) si
cs:ip=0000:7c03     7c03:	8e d8                	mov    ds,ax
                 ; bootsect.s:48  mov	ds,ax
(gdb) hbreak *0x9006c
(gdb) continue
cs:ip=9000:006c    9006c:	e8 c5 00             	call   0x90134
                 ; bootsect.s:110  call	kill_motor
```
- `cs:ip=9000:006c`: 세그먼트:오프셋. 선형 주소는 `cs*16+ip` (= `9006c`)
- `; bootsect.s:110 ...`: 지금 멈춘 원본 소스 파일과 줄 번호. `boot/bootsect.s` 110번째 줄이다
- 앞으로 몇 줄 더 보고 싶으면 `d16 10`
- 보호모드로 넘어가면 (`setup.s`의 `jmpi 0,8` 이후) 자동으로 32비트 + `tools/system` 심볼로 바뀌어 `main () at init/main.c:105`처럼 C 소스 줄이 나온다

TUI를 쓰고 싶으면 gdb 안에서 `layout regs`만 입력한다 (레지스터 창). `layout asm`은 쓰지 않는다. gdb는 16비트 코드를 32비트로 잘못 해석해서 `add BYTE PTR [eax],al` 같은 엉뚱한 명령을 보여 준다.

#### `si` 대신 중단점으로 건너뛰기
`int 0x13`(BIOS 디스크 읽기) 한 줄 안에서 BIOS 코드가 수만 개 실행되기 때문에 `si 50000` 같은 식으로는 진도가 안 나간다. 보고 싶은 지점에 `hbreak`를 걸고 `continue` 한다. `continue`는 다음 중단점까지 실행하고, 중단점이 없으면 끝(쉘)까지 간다.

| 주소 | 위치 (원본 소스) |
|---|---|
| `0x7c00` | bootsect 시작 |
| `0x90018` | `go:` (bootsect가 0x90000으로 옮겨진 직후) |
| `0x9003d` | `ok_load_setup:` (setup 4섹터 읽기 성공) |
| `0x9006c` | `call kill_motor` (커널 본체 로드 완료. `si`를 수만 번 하던 구간을 건너뜀) |
| `0x90093` | `jmpi 0,SETUPSEG` (setup으로 점프) |
| `0x90200` | setup 시작 |
| `0x90301` / `0x90304` | `lmsw ax`(보호모드 진입) / `jmpi 0,8` |
| `0x0` | `startup_32` (head.s) |
| `main`, `sys_setup`, `printk`, `panic` | 보호모드 전환 뒤 함수 이름으로 (`_` 없이) |

주소는 `output/bootsect.lst`, `output/setup.lst`의 오프셋(둘째 칸)에 로드 위치를 더한 값이다 (아래 로드 위치 표). 소스를 고치면 주소가 바뀌므로 리스팅에서 다시 확인한다.

| 명령 | 설명 |
|---|---|
| `stepi` (`si`) | 명령어 1개 실행. 정지할 때마다 현재 명령이 자동 출력됨 |
| `d16 [N]` | 현재 위치부터 N개 명령을 디스어셈블 (기본 5). CR0.PE를 보고 16/32비트를 자동 선택 |
| `x/8xb $cs*16+$pc` | 현재 위치 바이트 확인 (리얼모드) |
| `info registers` | 레지스터 확인 |
| `continue` | 다음 브레이크포인트까지 실행 |

종료: gdb에서 `quit` 후, 터미널 1에서 `Ctrl+C`. 남은 QEMU는 `pkill -f '^qemu-system-i386'` (`-x`는 프로세스 이름이 15자로 잘려서 맞지 않는다).

#### d16이 하는 일
`d16`은 커널 코드가 아니라 gdb 안에서만 도는 디버깅 명령이다 (`scripts/d16.py`). 기계어 바이트에는 16/32비트 표시가 없으므로 CPU 상태로 모드를 판별한다.

| 모드 | 판별 | 동작 |
|---|---|---|
| 리얼모드 | CR0.PE = 0 | `cs*16+ip`의 바이트를 읽어 `objdump -m i8086`으로 16비트 디스어셈블. 리스팅이 있으면 소스 `파일:줄`도 표시 |
| 보호모드 | CR0.PE = 1 이고 CS가 GDT 셀렉터 | `set architecture i386` + `tools/system` 심볼 로드 후 기본 `x/i`. `list`로 소스 줄까지 보인다 |

- `lmsw ax`(PE=1)와 `jmpi 0,8` 사이는 PE=1이지만 CS가 아직 리얼모드 값이라 16비트로 처리한다.
- CR0를 gdb가 못 읽으면 `monitor info registers`의 `CR0=`를 파싱하고, 그것도 안 되면 리얼모드로 가정한다.

#### 로드 위치 (리스팅 오프셋 → 주소)
`output/bootsect.elf`는 완성된 바이너리를 ELF로 감싼 것뿐이라 디버그 정보가 없다. 대신 as86 `-l` 리스팅이 `줄번호 오프셋 기계어 소스`를 1:1로 보여 준다.

| 구간 | 실제 주소 | 근거 |
|---|---|---|
| bootsect, 이동 전 | `0x7c00 + 오프셋` | BIOS가 로드 |
| bootsect, 이동 후 | `0x90000 + 오프셋` | `bootsect.s`의 `jmpi go,INITSEG` |
| setup | `0x90200 + 오프셋` (`cs=0x9020`, `ip=오프셋`) | `bootsect.s`의 `jmpi 0,SETUPSEG` |
| head (`startup_32`) | `0x0` | `setup.s`의 `jmpi 0,8` |

### 주의
- 리얼모드에서는 실제 주소가 `cs*16 + ip`이다. gdb의 `$pc`는 ip만 보여 준다. 브레이크포인트는 선형 주소로 건다 (예: `hbreak *0x7c00`).
- setup 구간(`cs=0x9020`)에서는 선형 주소로 건 `hbreak`에 멈춰도 `Breakpoint N` 대신 `Program received signal SIGTRAP`으로 표시된다. 정상이다.
- 보호모드 심볼(`tools/system`)은 `./2_build.sh`로 빌드해야 생긴다. C 심볼은 `System.map`에 `_main`처럼 보이지만 gdb에서는 `main`처럼 `_` 없이 쓴다.
- 포트 1234는 한 번에 하나의 gdb만 접속할 수 있다. VSCode 디버깅과 터미널 gdb를 동시에 쓰지 않는다.
- `scripts/qemu-debug.sh`는 시작할 때 남아 있는 QEMU를 모두 끈다.

## 부팅 순서 따라가기

전원 ON부터 쉘 프롬프트까지다. 주소와 값은 QEMU(`-m 16M`)에서 gdb로 실제로 확인한 것이다. 자세한 해설은 [docs/boot-guide.html](docs/boot-guide.html).

| # | 단계 | 코드 | 시작 주소 | 하는 일 | 화면 메시지 |
|---|---|---|---|---|---|
| 1 | 리셋 | CPU | `0xFFFF0` (`f000:fff0`) | 전원 ON 직후 CPU가 실행하는 첫 주소. `jmp f000:e05b`로 BIOS 본체로 점프 | |
| 2 | BIOS | SeaBIOS (ROM) | `0xF0000~0xFFFFF` | 하드웨어 검사(POST), IVT/BDA 채우기, 플로피 첫 섹터를 `0x7C00`에 읽고 끝 2바이트가 `55 AA`인지 확인 후 `jmp 0:7c00` | `SeaBIOS (version ...)`<br>`Booting from Floppy...` |
| 3 | bootsect | `boot/bootsect.s` | `0x7C00` | 자기 자신(512B)을 `0x90000`으로 복사하고 그쪽으로 점프 (`jmpi go,INITSEG`) | |
| 4 | | | `0x90018` (`go:`) | 스택을 `0x9000:0xFF00`에 잡고, setup 4섹터를 `0x90200`에 읽음 (`int 0x13`) | |
| 5 | | | `0x9003d` (`ok_load_setup:`) | 디스크의 트랙당 섹터 수 확인, 메시지 출력 (`int 0x10`) | `Loading system ...` |
| 6 | | | `call read_it` | 커널 본체(system)를 `0x10000`부터 읽음 (최대 192KB). `int 0x13`을 여러 번 부르는 가장 긴 구간 | |
| 7 | | | `0x9006c` (`call kill_motor`) | 플로피 모터 끄기, 루트 장치 결정 (`0x901FC`의 값. `tools/build.c`가 `ROOT_DEV=/dev/hd1`의 장치 번호 `0x0301`을 써 넣음) 후 `jmpi 0,SETUPSEG` | |
| 8 | setup | `boot/setup.s` | `0x90200` | BIOS를 불러 하드웨어 정보를 `0x90000~0x901FF`에 저장. BIOS를 쓰는 마지막 단계 | |
| 9 | | | | `cli` 후 system을 `0x10000~0x8FFFF` → `0x00000`으로 옮김. **이때 IVT(`0x0~0x3FF`)를 덮어쓰므로 이후로는 BIOS를 못 쓴다** | |
| 10 | | | | `lidt`/`lgdt`, A20 켜기(8042), 8259 인터럽트 컨트롤러를 `0x20~0x2F`로 재배치 | |
| 11 | | | `0x90301` / `0x90304` | `lmsw ax`로 보호모드(PE=1) 진입, `jmpi 0,8`로 GDT 코드 세그먼트의 0번지로 점프 | |
| 12 | head | `boot/head.s` | `0x0` (`startup_32`) | 세그먼트 레지스터, 스택, IDT(모두 `ignore_int`)·GDT 재설정, A20 확인, 수치 보조프로세서 확인 | |
| 13 | | | `setup_paging` | 페이지 디렉터리(`0x0`)와 페이지 테이블 4개(`0x1000~0x4FFF`)로 16MB를 1:1 매핑. 거꾸로 채우느라 켠 방향 플래그는 이 저장소가 넣은 `cld`로 끈다 | |
| 14 | main | `init/main.c` | `main` | 메모리 크기 계산, `mem_init` → `trap_init` → … → `floppy_init` → `sti` → `move_to_user_mode` → `fork` | |
| 15 | init (task 1) | `init()` → `kernel/blk_drv/hd.c` `sys_setup()` | | 하드디스크 파티션 테이블 읽기 (QEMU용으로 부팅 시 컨트롤러 리셋은 생략) | `Partition table ok.` |
| 16 | | `fs/super.c` `mount_root()` | | 루트 파일시스템(hd1) 마운트. 실패하면 panic | `46081/60000 free blocks`<br>`19232/20000 free inodes` |
| 17 | | `init()` | | `/dev/tty0`을 열고 버퍼·메모리 정보 출력 | `3466 buffers = 3549184 bytes buffer space`<br>`Free mem: 12451840 bytes` |
| 18 | /etc/rc | 디스크 이미지의 `/etc/rc` | | `/etc/update &` 후 `echo " Ok. "` | ` Ok.` |
| 19 | 로그인 쉘 | `/bin/sh` | | `HOME=/usr/root`로 쉘 실행 | `[/usr/root]# ` |

마지막으로 보인 메시지로 어디서 멈췄는지 알 수 있다.
- `Booting from Floppy...`까지만 → BIOS가 부트섹터를 못 읽음 (Image 문제)
- `Loading system ...` 뒤에 아무것도 없음 → 6~14 사이. 이 구간은 화면 출력이 없다
- `harddisk I/O error` → 하드디스크 이미지가 안 붙음 (15번)
- `Kernel panic: Unable to mount root` → 루트 장치(`0x901FC`)와 디스크가 안 맞음 (16번)

### BIOS가 쓰는 영역 (리얼모드 1MB 메모리 맵)

| 주소 | 크기 | 내용 | 확인 (0x7c00에서 멈춘 상태) |
|---|---|---|---|
| `0x00000~0x003FF` | 1KB | IVT (인터럽트 벡터 테이블). `int N`의 벡터는 `N*4`번지 | `x/2xh 0x4c` → `0xe3fe 0xf000` (`int 0x13` → 시스템 BIOS) |
| `0x00400~0x004FF` | 256B | BDA (BIOS 데이터 영역) | `x/1dh 0x413` → `639` (기본 메모리 KB) |
| `0x07C00~0x07DFF` | 512B | BIOS가 읽어 온 부트섹터 | `x/2xb 0x7dfe` → `0x55 0xaa` |
| `0x9FC00~0x9FFFF` | 1KB | EBDA (확장 BIOS 데이터 영역) | `x/1xh 0x40e` → `0x9fc0` |
| `0xA0000~0xBFFFF` | 128KB | 비디오 메모리. 텍스트 화면은 `0xB8000` | `x/8xb 0xb8000` |
| `0xC0000~0xCAFFF` | 44KB | VGA BIOS ROM (`int 0x10`) | |
| `0xF0000~0xFFFFF` | 64KB | **시스템 BIOS ROM (SeaBIOS)**. 맨 끝 `0xFFFF0`이 리셋 벡터 | `info registers cs eip` |
| `0x100000~` | | 확장 메모리 (A20을 켜야 접근 가능) | |

QEMU가 실제로 나눈 맵은 gdb에서 `monitor info mtree -f`로 볼 수 있다.

### 커널이 올라간 뒤의 메모리 (16MB)

| 주소 | 내용 |
|---|---|
| `0x00000~0x00FFF` | 페이지 디렉터리 (`pg_dir`). 원래 head.s 코드가 있던 자리 |
| `0x01000~0x04FFF` | 페이지 테이블 4개 (`pg0~pg3`) |
| `0x05000~0x053FF` | `tmp_floppy_area` (플로피 DMA 버퍼) |
| `0x054B8` / `0x05CB8` | `idt` / `gdt` |
| `0x06757` | `main` |
| `~0x1EECC` | 커널 끝 (`_end`) |
| `_end~0x3FFFFF` | 버퍼 캐시 (`0xA0000~0xFFFFF`는 건너뜀) |
| `0x400000~0xFDFFFF` | 주 메모리. `Free mem: 12451840` = `0xFE0000 - 0x400000` |

### 메시지 따라가기 (gdb)

커널 메시지는 전부 `printk`를 거친다. 보호모드로 넘어간 뒤 `printk`와 `panic`에 중단점을 걸면, 멈출 때마다 메시지 원문과 `bt`로 누가 찍었는지 볼 수 있다.
```
(gdb) hbreak *0x0           # startup_32. d16이 tools/system 심볼을 자동으로 불러온다
(gdb) continue
(gdb) hbreak printk
(gdb) hbreak panic
(gdb) continue
Breakpoint 4, printk (fmt=0x13aec "Partition table%s ok.\n\r") at printk.c:22
(gdb) bt 3
#0  printk (fmt=0x13aec "Partition table%s ok.\n\r") at printk.c:22
#1  0x000100f4 in sys_setup (BIOS=<optimized out>) at hd.c:157
#2  0x0000719d in _system_call ()
```
`N buffers ...`, `Free mem ...`은 사용자 모드 `printf`라서 `printk`에 걸리지 않는다. ` Ok.`와 프롬프트는 디스크 이미지 안의 프로그램이 찍는다.

## 라이선스와 출처

- **Linux 0.11** © 1991 Linus Torvalds. 원본 파일의 저작권 표시는 그대로 두었다. 0.11은 Linus의 자체 조건(소스 공개, 무료 배포, 저작권 표시 유지)으로 배포되었고, 0.12부터 GPL로 바뀌었다. 이 저장소는 [GPL v2](LICENSE)로 배포한다.
- 이 저장소는 [yuan-xy/Linux-0.11](https://github.com/yuan-xy/Linux-0.11)의 fork에서 시작했다. 그 판은 falcon(wuzhangjin)이 현대 gcc용으로 고친 판을 바탕으로 한다. 커널 소스는 원본으로 되돌렸고, `hd.c`의 QEMU 호환 수정은 그 판을 참고했다.
- `hdc-0.11.img`는 fork 원본에 있던 이미지로, [oldlinux.org](http://www.oldlinux.org)에서 배포하는 Linux 0.11용 루트 파일시스템이다. 안에 든 프로그램(gcc, sh 등)은 각자의 라이선스를 따른다.
- 원본에서 무엇을 언제 바꿨는지는 "원본과 다른 점" 표와 커밋 이력(`Linux 0.11 원본 소스로 교체` 다음 커밋)에 있다.
