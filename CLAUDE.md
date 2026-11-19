# CLAUDE.md

Linux 0.11(1991) 원본 소스를 WSL 안의 Docker 컨테이너(Ubuntu 14.04, gcc 4.8)에서 빌드하고, WSL의 QEMU로 부팅하며 gdb로 부팅 과정을 따라가는 학습용 저장소다. 사용자와는 한국어로 대화한다.

## 원칙: 원본을 지킨다

- 저장소 루트의 커널 소스(`boot/`, `fs/`, `include/`, `init/`, `kernel/`, `lib/`, `mm/`, `tools/build.c`, `Makefile`)는 원본에 **gcc 4.8 빌드와 QEMU 부팅에 꼭 필요한 것만** 고친 것이다. 사용자는 원본에서 벗어나는 것을 원하지 않는다. 고칠 때는 원본을 가장 덜 바꾸는 방법을 고른다.
- `linux-0.11-original/`은 Linus의 원본 그대로다. 참조용이고 빌드하지 않으며 고치지 않는다. 패치 전체는 `diff -r linux-0.11-original . -x linux-0.11-original -x .git`.
- `bootsect.s`, `setup.s`(as86 문법), `tools/build.c`, 커널 `.s` 파일은 원본과 같다. C 심볼은 `-fleading-underscore`로 `_main`처럼 되고, gdb에서는 `main`처럼 `_` 없이 쓴다.
- **라이선스:** 원본 파일의 `(C) 1991 Linus Torvalds` 표시는 절대 지우거나 바꾸지 않는다. 소스에는 실제로 고친 코드만 넣고, 이름이나 수정 내역 주석 덩어리는 넣지 않는다. 무엇을 언제 왜 고쳤는지는 README 표와 커밋 메시지에 남긴다. `LICENSE`(GPL v2)와 README의 "License and credits"도 유지한다.
- 소스를 바꾸면 README의 "Changes from the original" / "원본과 다른 점" 표도 갱신한다.

## 빌드와 실행

```bash
./1_init.sh        # 처음 한 번: 이미지 빌드, 컨테이너 linux-0.11 시작
./2_build.sh       # 빌드 -> output/ (Image, hdc-0.11.img, 부트 디버깅 파일). 컨테이너가 꺼져 있으면 먼저 띄움
./3_run.sh         # QEMU로 부팅
./4_debug_qemu.sh  # 부트로더 디버깅 터미널 1 (QEMU가 gdb 대기)
./5_debug_gdb.sh   # 부트로더 디버깅 터미널 2 (gdb)
./9_clean.sh       # make clean
```

- 실행하는 스크립트는 루트에 번호를 붙여 순서대로 둔다. 내부용(`qemu-debug.sh`, `gdb-boot.gdb`, `d16.py`)은 `scripts/`에 둔다.
- 빌드는 컨테이너 안에서 저장소 루트를 `/build`로 마운트해서 한다. QEMU, gdb, `scripts/d16.py`는 WSL에서 돈다.
- 원본 최상위 Makefile은 하위 디렉터리 결과물(`fs/fs.o` 등)이 있으면 다시 들어가지 않는다. `2_build.sh`가 하위 디렉터리를 먼저 `make` 한다.
- 저장소가 Windows 드라이브(`/mnt/d/...`)에 있으면 대소문자를 구분하지 않는다 (`keyboard.s` = `keyboard.S`).
- main 이후 디버깅은 VSCode F5 (`.vscode/tasks.json`이 `2_build.sh`와 `scripts/qemu-debug.sh`를 부른다).
- `scripts/qemu-debug.sh`(`4_debug_qemu.sh`)는 시작할 때 실행 중인 QEMU를 모두 끈다. 사용자가 띄운 QEMU가 있을 수 있으니, 테스트할 때는 이미지를 복사해서 따로 띄우고 자기가 띄운 프로세스만 PID로 끈다.
- 남은 QEMU 정리: `pkill -f '^qemu-system-i386'` (`-x`는 이름이 15자로 잘려서 안 맞는다).

## 문서 (한국어, 영어 둘 다 유지)

- `README.md`(영어) / `README.ko.md`(한국어): 구성, 개발 환경, 원본과 다른 점, 디버깅, 부팅 순서, 라이선스.
- `docs/boot-guide.en.html`(영어) / `docs/boot-guide.html`(한국어): 부팅 해설. 소스 줄 번호, 주소, 크기, 화면 메시지 값을 인용하므로 소스를 바꾸면 두 언어 모두 맞춘다.
- 한쪽 언어만 고치지 않는다. 내용은 두 언어가 같아야 한다.
