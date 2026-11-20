# Linux 0.11 (WSL + Docker + QEMU)

**English** | [한국어](README.ko.md)

Linus Torvalds' original Linux 0.11 (1991) source, **built in a Docker container inside WSL**, **booted with QEMU in WSL**, and **followed step by step with gdb from power-on to the shell prompt**. It is a repository for learning how the kernel boots.

- The kernel source is the original with **only what gcc 4.8 and QEMU strictly need** changed. `bootsect.s`, `setup.s`, `tools/build.c` and the kernel `.s` files are untouched. The pristine original is the [linux-0.11.tar.gz](https://www.kernel.org/pub/linux/kernel/Historic/linux-0.11.tar.gz) on kernel.org.
- The boot loader (16-bit real mode) is debugged with gdb in a terminal; from `startup_32` on (32-bit protected mode) with F5 in VSCode.
- Boot walkthrough: [docs/boot-guide.en.html](docs/boot-guide.en.html) (Korean: [docs/boot-guide.html](docs/boot-guide.html)). Open it in a browser after cloning.

## Layout

| Path | What |
|---|---|
| `boot/`, `fs/`, `include/`, `init/`, `kernel/`, `lib/`, `mm/`, `tools/build.c`, `Makefile` | Kernel source (original + minimal patches) |
| `hdc-0.11.img` | Root file system hard disk image (`/bin/sh`, `gcc`, ...) |
| `Dockerfile`, `docker-compose.yml` | Build environment (Ubuntu 14.04, gcc 4.8, bin86) |
| `1_init.sh` ~ `5_debug_gdb.sh`, `9_clean.sh` | What you run, numbered in order (see [Getting started](#getting-started)) |
| `scripts/` | Used by the numbered scripts and VSCode: QEMU with a gdbstub, gdb settings, the `d16` command |
| `.vscode/` | VSCode build tasks, F5 debug configurations, recommended extensions |
| `docs/` | Boot walkthrough (Korean, English) |

## Environment

Everything lives in one WSL2 instance on Windows. No Docker Desktop: **Docker Engine is installed inside WSL**.

```
Windows ── VSCode ──(WSL extension)──> WSL2 (Ubuntu 24.04)
                                        ├─ Docker Engine ── container linux-0.11 (Ubuntu 14.04, gcc 4.8, bin86)
                                        │                     └ mounts the repository at /build, results go to output/
                                        ├─ QEMU (qemu-system-i386) ── boots output/Image + output/hdc-0.11.img
                                        └─ gdb + python3 (scripts/d16.py) ── attaches to the QEMU gdbstub (localhost:1234)
```

| Tool | Version used | Install (WSL) |
|---|---|---|
| Docker Engine, Docker Compose | 29.9, v5.6 | Docker's official "Install Docker Engine on Ubuntu" instructions |
| QEMU | 8.2.2 | `sudo apt install qemu-system-x86` |
| gdb | 15.1 | `sudo apt install gdb` (with Python support) |
| python3, objdump | 3.12, binutils 2.42 | `sudo apt install python3 binutils` (`d16` uses objdump for 16-bit disassembly) |
| In the container | gcc 4.8.4, make, bin86 (as86/ld86) | installed by the `Dockerfile` |

The QEMU window shows up on Windows through WSLg.

**Why Ubuntu 14.04:** gcc 4.8 is the compiler that builds the original with the fewest changes. 14.04 is out of support and its package archive is slow (building the image takes over 15 minutes); if the archive disappears, the image can no longer be rebuilt. Ubuntu 24.04 (gcc 13) was tried as well: with `-fgnu89-inline -fno-pie -fcf-protection=none` and the like, and with `attr` in `console.c` kept from being optimized away, it builds, but after `/etc/rc` it panics with `Kernel panic: free_page_tables called with wrong alignment`. gcc 13's optimizer seems to break more of the 1991 code's assumptions, which would mean more changes to the original, so 14.04 stays for now.

### VSCode extensions

`.vscode/extensions.json` recommends these when the folder is opened.

| Extension | Install on | Used for |
|---|---|---|
| WSL (`ms-vscode-remote.remote-wsl`, part of the Remote Development pack) | Windows | Open the folder with **"WSL: Open Folder in WSL"** |
| C/C++ (`ms-vscode.cpptools`) | WSL | F5 debugging (`cppdbg` → gdb), code navigation |
| Container Tools (`ms-azuretools.vscode-containers`) | WSL | Inspecting the container (optional) |

The C/C++ extension must be installed **on the WSL side**: open the folder in WSL, then press "Install in WSL" in the Extensions view.

## Getting started

Run the numbered scripts in order, in a WSL terminal at the repository root.

| Script | What it does | When |
|---|---|---|
| `./1_init.sh` | Builds the Docker image (Ubuntu 14.04, gcc 4.8, bin86) and starts the build container `linux-0.11` (`docker compose build --no-cache && docker compose up -d`) | Once. Takes 15+ minutes (the Ubuntu 14.04 package archive is slow) |
| `./2_build.sh` | Builds the kernel inside the container and copies the results to `output/`: `Image`, `hdc-0.11.img`, and the boot-debug files (`bootsect.elf`, `*.lst`). Starts the container first if it is not running, e.g. after a reboot | After every source change |
| `./3_run.sh` | Boots with QEMU in WSL; the window opens on Windows through WSLg | To run it |
| `./4_debug_qemu.sh` | Boot loader debugging, terminal 1: QEMU halted, waiting for gdb | To debug the boot loader |
| `./5_debug_gdb.sh` | Boot loader debugging, terminal 2: gdb, stops at 0x7c00 | Together with 4 |
| `./9_clean.sh` | `make clean` in the container | When needed |

From cloning to the shell prompt:

```bash
# tools (see Environment); log in again after adding yourself to the docker group
sudo apt install qemu-system-x86 gdb python3 binutils
sudo usermod -aG docker $USER

git clone https://github.com/hakhong/Linux-0.11.git
cd Linux-0.11
./1_init.sh        # once
./2_build.sh
./3_run.sh
```

`2_build.sh` makes each subdirectory before the top level, because the original top-level Makefile does not descend into a directory whose archive (`fs/fs.o`, ...) already exists.

The boot ends at the `[/usr/root]#` prompt; `gcc -o hello hello.c && ./hello` works inside. The disk image also holds `iam` and `whoami`, lab programs from the earlier fork; the original kernel has no such system calls, so they do not run.

## Changes from the original

The original targets **gcc 1.x and a.out** (1991); the build environment has **gcc 4.8**. Nothing was changed for optimization: only what today's compiler rejects or treats differently, each in the way that changes the original the least. 26 files are changed. The source contains only the actual code changes; what was changed, when and why is recorded in the table below and in the commit history. The commit right after "Linux 0.11 원본 소스로 교체" (replace with the original source) is the whole patch.

| Kind | Files | Change | Why |
|---|---|---|---|
| Toolchain | `Makefile`, 7 sub-`Makefile`s | `gas`/`gld`/`gar` → `as --32`/`ld -m elf_i386`/`ar`. gcc gets `-m32 -g -fleading-underscore -fno-builtin -fno-stack-protector`; gcc 1.x-only options (`-fcombine-regs`, `-mstring-insns`) removed | Today's tools produce 32-bit ELF. With `-fleading-underscore` C symbols get the a.out-style `_`, so the original `.s` files (`_main`, `_schedule`, ...) are used as they are |
| Making the Image | `Makefile` | `tools/build` built with `-m32` and `MAJOR`/`MINOR` mapped to `major`/`minor`. `ROOT_DEV=/dev/hd1`, created with `mknod` if the container lacks it. `tools/build` gets `tools/kernel` (the raw kernel behind 1024 zero bytes) instead of the ELF `tools/system`. as86 listings (`-l`); `System.map` from `nm` | So the original `build.c` is used unchanged (it assumes a 32-bit host, an a.out header and a device node) |
| Keyboard rule | `kernel/chr_drv/Makefile` | `keyboard.S` goes through `cpp \| as` straight to `keyboard.o`, without the intermediate `keyboard.s` | A Windows drive (`/mnt/d`) is case-insensitive: `keyboard.s` is `keyboard.S`, so with the original rule `make clean` deletes the source |
| Inline asm | `string.h`, `asm/memory.h`, `linux/sched.h`, `mm/memory.c`, `fs/bitmap.c`, `fs/buffer.c`, `fs/namei.c`, `chr_drv/console.c`, `blk_drv/hd.c`, `blk_drv/floppy.c` | asm statements that list an input register as clobbered now tie it to a dummy output (`d0`, `d1`, ...). `__volatile__` where an asm gained outputs, `"memory"` where it writes memory | Since gcc 3 this is an `impossible constraints` error. Just dropping the clobber would let gcc reuse the changed register. The asm bodies are unchanged; only `%N` numbers shifted by the new operands are adjusted |
| Byte registers | `asm/segment.h` | `"r"` → `"q"` in `get_fs_byte`/`put_fs_byte` | With `"r"` gcc may pick `%esi`, giving `%sil`, which does not exist in 32-bit mode |
| Direction flag | `boot/head.s`, `mm/memory.c`, `string.h` (memmove), `chr_drv/console.c` (scrdown) | `cld` at the end of asm that uses `std` | gcc 4.8 assumes DF=0 and compiles struct copies to `rep movsl`. Without this, fork's struct copy right after `get_free_page()` runs backwards and task 1 (init) never runs |
| Old syntax | `lib/malloc.c`, `fs/exec.c`, `blk_drv/blk.h`, `chr_drv/keyboard.S`, `boot/head.s`, `init/main.c` | cast as lvalue → plain assignment, `#elif` → `#else`, `xorl %al,%al` → `xorl %eax,%eax`, `.align 3` → `.align 8`, `static` dropped from `fork`/`pause`/`sync` in main.c | gcc 1.x and old gas accepted these; they are errors now. `.align n` means 2ⁿ bytes in a.out but n bytes in ELF. fork/pause are verified to still be inlined into main |
| QEMU | `blk_drv/hd.c` | `controller_ready()` waits only for BUSY to clear; no controller reset at boot (`reset = 0`) | SeaBIOS leaves the (absent) slave selected, so the status reads 0x00, and QEMU does not set READY after the original soft reset. Otherwise: panic `HD controller not ready` |
| Keyboard layout | `include/linux/config.h` | `KBD_FINNISH` → `KBD_US` | The original default is Finnish: on a US/Korean keyboard `/` types `-`, `-` types `+`, `>` types `:`. It picks another table already in the original; the kernel size is the same |

- The kernel is about 107 KB. `-O` is used, as in the original Makefile; it is also what inlines `fork()`/`pause()` into `main()` so task 0 does not touch the stack after fork. gdb may therefore show some variables as `<optimized out>`.
- Build warnings (`volatile void`, suggested parentheses, ...) come from 1991 code and do not affect behaviour.

## Debugging

### main (VSCode)
F5 → `Linux 0.11 - main (QEMU + gdb)`. It builds, starts QEMU and stops first at `startup_32` (0x0); F5 again stops at `main`. F10/F11 work from there.

VSCode shows an "Exception has occurred" popup (`Hit breakpoint 3 at 0x6757.`) at these stops. It is not an error. `startup_32` and `main` are `hbreak`s set in `launch.json` (`postRemoteConnectCommands`), and cppdbg labels a stop at a breakpoint it did not set itself as an exception. The stop position and source line are correct, and stepping and continuing work normally.

### Boot loader (VSCode)
Pick `Linux 0.11 - bootsect (QEMU + gdb)` in the Run and Debug dropdown and press F5. It builds, starts QEMU halted and stops at 0x7c00, where the BIOS runs the boot sector. On connect it resets the VM (`monitor system_reset`), so a QEMU left running from an earlier session stops there too.

The Debug Console prints a list of commands and key addresses at the first stop (`bhelp`; run `-exec bhelp` to show it again). Type gdb commands there with the `-exec` prefix. Without it the console tries to evaluate an expression and fails with `Cannot evaluate expression on the specified stack frame.`

| Debug Console | What it does |
|---|---|
| `-exec si` / `-exec ni` | Run one instruction (`ni` steps over a `call`) |
| `-exec continue` | Run to the next breakpoint, or to the shell if there is none |
| `-exec hbreak *0x9006c` | Breakpoint at a linear address (see the address table under "Boot loader (two terminals)") |
| `-exec d16 10` | Show the next 10 instructions with the original source lines |
| `-exec d16 1` | Show the current instruction (the terminal does this by itself at every stop) |
| `-exec info registers` | All registers |
| `-exec info breakpoints` | List breakpoints |

`d16` is loaded by `postRemoteConnectCommands` in `launch.json`. The terminal method below prints the current instruction at every stop and has the TUI register window, so it is more convenient for stepping through the boot loader.

### Boot loader (two terminals)
Without VSCode: two WSL terminals, both in the repository root. The VSCode way is in the section above.

1. Build (once, or after changing the source): `./2_build.sh`. It also makes `output/bootsect.elf` and the listings `output/bootsect.lst`, `output/setup.lst`.
2. Terminal 1: `./4_debug_qemu.sh`. QEMU waits for gdb (ready when `QEMU gdbstub ready` appears). It boots `output/Image` and attaches `output/hdc-0.11.img`, so `continue` reaches the shell.
3. Terminal 2: `./5_debug_gdb.sh`. gdb stops at 0x7c00, where the BIOS runs the boot sector.

#### Windows

| Window | Started by | Role |
|---|---|---|
| Terminal 1 | `4_debug_qemu.sh` | Starts QEMU halted and waits for gdb |
| QEMU screen | opened by terminal 1 | The boot screen (`Loading system ...`, kernel messages, shell) |
| Terminal 2 | `5_debug_gdb.sh` | gdb; type `si`, `continue`, ... here |

No need for `gdb -tui`. `5_debug_gdb.sh` runs `scripts/gdb-boot.gdb`:
```
set architecture i8086
source scripts/d16.py
define hook-stop      # run d16 1 at every stop
  d16 1
end
target remote localhost:1234
hbreak *0x7c00
continue
```

#### Where am I?
At every stop, whether from `si` or `continue`, `hook-stop` prints the current instruction and the original source line.
```
(gdb) si
cs:ip=0000:7c03     7c03:	8e d8                	mov    ds,ax
                 ; bootsect.s:48  mov	ds,ax
(gdb) hbreak *0x9006c
(gdb) continue
cs:ip=9000:006c    9006c:	e8 c5 00             	call   0x90134
                 ; bootsect.s:110  call	kill_motor
```
- `cs:ip=9000:006c`: segment:offset; the linear address is `cs*16+ip` (= `9006c`)
- `; bootsect.s:110 ...`: the original source file and line, i.e. line 110 of `boot/bootsect.s`
- `d16 10` shows the next ten instructions
- After the switch to protected mode (`jmpi 0,8` in `setup.s`) it changes to 32-bit and the `tools/system` symbols by itself, and C lines appear, e.g. `main () at init/main.c:105`

For a TUI, type only `layout regs` (register window). Avoid `layout asm`: gdb decodes the 16-bit code as 32-bit and shows nonsense like `add BYTE PTR [eax],al`.

#### Commands (terminal 2)
`5_debug_gdb.sh` prints this list when gdb starts.

| Command | What it does |
|---|---|
| `si` / `ni` | Run one instruction (`ni` steps over a `call`) |
| `continue` (`c`) | Run to the next breakpoint, or to the shell if there is none |
| `hbreak *0x9006c` | Breakpoint at a linear address (see the table below) |
| `info breakpoints` / `delete N` | List breakpoints / remove number N |
| `d16 10` | Show the next 10 instructions with the original source lines |
| `x/10i $cs*16+$pc` | Raw disassembly at the real address |
| `info registers` / `p/x $ax` | All registers / one register |
| `layout regs` | Register window (TUI) |
| `quit` | Leave gdb (stop QEMU in terminal 1 with Ctrl+C) |

#### Skip with breakpoints instead of `si`
A single `int 0x13` (BIOS disk read) runs tens of thousands of BIOS instructions, so `si 50000` gets nowhere. Put an `hbreak` where you want to look and `continue`. `continue` runs to the next breakpoint, or to the end (the shell) if there is none.

| Address | Where (original source) |
|---|---|
| `0x7c00` | bootsect start |
| `0x90018` | `go:` (right after bootsect moved itself to 0x90000) |
| `0x9003d` | `ok_load_setup:` (the four setup sectors were read) |
| `0x9006c` | `call kill_motor` (kernel loaded; skips the part that took tens of thousands of `si`) |
| `0x90093` | `jmpi 0,SETUPSEG` (jump to setup) |
| `0x90200` | setup start |
| `0x90301` / `0x90304` | `lmsw ax` (enter protected mode) / `jmpi 0,8` |
| `0x0` | `startup_32` (head.s) |
| `main`, `sys_setup`, `printk`, `panic` | by function name (without `_`) after the switch to protected mode |

An address is the offset (second column) in `output/bootsect.lst` / `output/setup.lst` plus the load address (table below). Addresses move when the source changes, so look them up in the listing again.

| Command | Description |
|---|---|
| `stepi` (`si`) | Execute one instruction; the current instruction is printed at every stop |
| `d16 [N]` | Disassemble N instructions from here (default 5), 16/32-bit chosen from CR0.PE |
| `x/8xb $cs*16+$pc` | Bytes at the current position (real mode) |
| `info registers` | Registers |
| `continue` | Run to the next breakpoint |

To finish: `quit` in gdb, then `Ctrl+C` in terminal 1. Kill a leftover QEMU with `pkill -f '^qemu-system-i386'` (`-x` does not match: the process name is cut to 15 characters).

#### What d16 does
`d16` is not kernel code but a gdb command (`scripts/d16.py`). Machine code has no 16/32-bit marker, so it decides the mode from the CPU state.

| Mode | Test | Action |
|---|---|---|
| Real mode | CR0.PE = 0 | Reads the bytes at `cs*16+ip` and disassembles them as 16-bit with `objdump -m i8086`; adds the source `file:line` from the listing |
| Protected mode | CR0.PE = 1 and CS is a GDT selector | `set architecture i386`, loads the `tools/system` symbols, then plain `x/i`; `list` shows source lines |

- Between `lmsw ax` (PE=1) and `jmpi 0,8` PE is already 1 but CS still holds the real-mode value, so it is treated as 16-bit.
- If gdb cannot read CR0 it parses `CR0=` from `monitor info registers`, and failing that assumes real mode.

#### Load addresses (listing offset → address)
`output/bootsect.elf` only wraps the finished binary in ELF, so it has no debug info. The as86 `-l` listings map `line offset machine-code source` one to one instead.

| Part | Address | Because of |
|---|---|---|
| bootsect, before moving | `0x7c00 + offset` | loaded there by the BIOS |
| bootsect, after moving | `0x90000 + offset` | `jmpi go,INITSEG` in `bootsect.s` |
| setup | `0x90200 + offset` (`cs=0x9020`, `ip=offset`) | `jmpi 0,SETUPSEG` in `bootsect.s` |
| head (`startup_32`) | `0x0` | `jmpi 0,8` in `setup.s` |

### Notes
- In real mode the address is `cs*16 + ip`; gdb's `$pc` shows only ip. Set breakpoints at linear addresses (e.g. `hbreak *0x7c00`).
- In setup (`cs=0x9020`) a stop at an `hbreak` on a linear address shows `Program received signal SIGTRAP` instead of `Breakpoint N`. That is expected.
- The protected-mode symbols (`tools/system`) exist only after `./2_build.sh`. C symbols appear as `_main` in `System.map` but are used without `_` in gdb (`main`).
- Only one gdb can attach to port 1234 at a time; do not use VSCode debugging and terminal gdb together.
- `scripts/qemu-debug.sh` kills any running QEMU when it starts.

## Following the boot

From power-on to the shell prompt. Addresses and values were checked with gdb in QEMU (`-m 16M`). The full walkthrough is in [docs/boot-guide.en.html](docs/boot-guide.en.html).

| # | Stage | Code | Start | What happens | On screen |
|---|---|---|---|---|---|
| 1 | Reset | CPU | `0xFFFF0` (`f000:fff0`) | The first address the CPU runs after power-on; `jmp f000:e05b` into the BIOS | |
| 2 | BIOS | SeaBIOS (ROM) | `0xF0000~0xFFFFF` | POST, fills the IVT/BDA, reads the first floppy sector to `0x7C00`, checks the `55 AA` signature, `jmp 0:7c00` | `SeaBIOS (version ...)`<br>`Booting from Floppy...` |
| 3 | bootsect | `boot/bootsect.s` | `0x7C00` | Copies itself (512 B) to `0x90000` and jumps there (`jmpi go,INITSEG`) | |
| 4 | | | `0x90018` (`go:`) | Stack at `0x9000:0xFF00`; reads 4 setup sectors to `0x90200` (`int 0x13`) | |
| 5 | | | `0x9003d` (`ok_load_setup:`) | Gets sectors per track, prints the message (`int 0x10`) | `Loading system ...` |
| 6 | | | `call read_it` | Reads the kernel (system) to `0x10000` (up to 192 KB); the longest part, many `int 0x13` calls | |
| 7 | | | `0x9006c` (`call kill_motor`) | Stops the floppy motor, picks the root device (the word at `0x901FC`; `tools/build.c` wrote `0x0301` from `ROOT_DEV=/dev/hd1`), `jmpi 0,SETUPSEG` | |
| 8 | setup | `boot/setup.s` | `0x90200` | Asks the BIOS for hardware data and stores it at `0x90000~0x901FF`; the last stage that uses the BIOS | |
| 9 | | | | `cli`, then moves system from `0x10000~0x8FFFF` to `0x00000`. **This overwrites the IVT (`0x0~0x3FF`), so the BIOS cannot be used any more** | |
| 10 | | | | `lidt`/`lgdt`, A20 on (8042), reprograms the 8259 interrupt controllers to `0x20~0x2F` | |
| 11 | | | `0x90301` / `0x90304` | `lmsw ax` enters protected mode (PE=1); `jmpi 0,8` jumps to offset 0 of the GDT code segment | |
| 12 | head | `boot/head.s` | `0x0` (`startup_32`) | Segment registers, stack, IDT (all `ignore_int`) and GDT, checks A20 and the math coprocessor | |
| 13 | | | `setup_paging` | Page directory (`0x0`) and four page tables (`0x1000~0x4FFF`) map 16 MB 1:1. The direction flag set for the backward fill is cleared by the `cld` this repository adds | |
| 14 | main | `init/main.c` | `main` | Memory size, `mem_init` → `trap_init` → … → `floppy_init` → `sti` → `move_to_user_mode` → `fork` | |
| 15 | init (task 1) | `init()` → `kernel/blk_drv/hd.c` `sys_setup()` | | Reads the hard disk partition table (the controller reset at boot is skipped for QEMU) | `Partition table ok.` |
| 16 | | `fs/super.c` `mount_root()` | | Mounts the root file system (hd1); panics on failure | `46081/60000 free blocks`<br>`19232/20000 free inodes` |
| 17 | | `init()` | | Opens `/dev/tty0`, prints buffer and memory info | `3466 buffers = 3549184 bytes buffer space`<br>`Free mem: 12451840 bytes` |
| 18 | /etc/rc | `/etc/rc` on the disk image | | `/etc/update &`, then `echo " Ok. "` | ` Ok.` |
| 19 | Login shell | `/bin/sh` | | Shell with `HOME=/usr/root` | `[/usr/root]# ` |

The last message on screen tells you where it stopped.
- Only `Booting from Floppy...` → the BIOS could not read the boot sector (Image problem)
- Nothing after `Loading system ...` → somewhere in 6–14; that part prints nothing
- `harddisk I/O error` → no hard disk image attached (15)
- `Kernel panic: Unable to mount root` → root device (`0x901FC`) and disk do not match (16)

### Memory used by the BIOS (the 1 MB real-mode map)

| Address | Size | What | Check (stopped at 0x7c00) |
|---|---|---|---|
| `0x00000~0x003FF` | 1 KB | IVT (interrupt vector table); the vector of `int N` is at `N*4` | `x/2xh 0x4c` → `0xe3fe 0xf000` (`int 0x13` → system BIOS) |
| `0x00400~0x004FF` | 256 B | BDA (BIOS data area) | `x/1dh 0x413` → `639` (base memory, KB) |
| `0x07C00~0x07DFF` | 512 B | The boot sector loaded by the BIOS | `x/2xb 0x7dfe` → `0x55 0xaa` |
| `0x9FC00~0x9FFFF` | 1 KB | EBDA (extended BIOS data area) | `x/1xh 0x40e` → `0x9fc0` |
| `0xA0000~0xBFFFF` | 128 KB | Video memory; text screen at `0xB8000` | `x/8xb 0xb8000` |
| `0xC0000~0xCAFFF` | 44 KB | VGA BIOS ROM (`int 0x10`) | |
| `0xF0000~0xFFFFF` | 64 KB | **System BIOS ROM (SeaBIOS)**; the reset vector `0xFFFF0` is at its end | `info registers cs eip` |
| `0x100000~` | | Extended memory (needs A20) | |

gdb shows QEMU's actual map with `monitor info mtree -f`.

### Memory after the kernel is up (16 MB)

| Address | What |
|---|---|
| `0x00000~0x00FFF` | Page directory (`pg_dir`), where head.s code used to be |
| `0x01000~0x04FFF` | Four page tables (`pg0~pg3`) |
| `0x05000~0x053FF` | `tmp_floppy_area` (floppy DMA buffer) |
| `0x054B8` / `0x05CB8` | `idt` / `gdt` |
| `0x06757` | `main` |
| `~0x1EECC` | End of the kernel (`_end`) |
| `_end~0x3FFFFF` | Buffer cache (skips `0xA0000~0xFFFFF`) |
| `0x400000~0xFDFFFF` | Main memory. `Free mem: 12451840` = `0xFE0000 - 0x400000` |

### Following the messages (gdb)

Every kernel message goes through `printk`. With breakpoints on `printk` and `panic` after the switch to protected mode, each stop shows the message and `bt` shows who printed it.
```
(gdb) hbreak *0x0           # startup_32; d16 loads the tools/system symbols
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
`N buffers ...` and `Free mem ...` come from a user-mode `printf`, so `printk` does not catch them. ` Ok.` and the prompt are printed by programs on the disk image.

## License and credits

- **Linux 0.11** © 1991 Linus Torvalds. The copyright notices in the original files are kept as they are. 0.11 was released under Linus' own terms (source available, no fee, notices kept); Linux moved to the GPL from 0.12. This repository is distributed under the [GPL v2](LICENSE).
- This repository started as a fork of [yuan-xy/Linux-0.11](https://github.com/yuan-xy/Linux-0.11), which builds on falcon's (wuzhangjin) port to modern gcc. The kernel source was taken back to the original; the QEMU fix in `hd.c` follows that port.
- `hdc-0.11.img` is the image from the original fork: the Linux 0.11 root file system distributed by [oldlinux.org](http://www.oldlinux.org). The programs on it (gcc, sh, ...) are under their own licenses.
- What was changed from the original, and when, is listed under "Changes from the original" and in the commit history (the commit after "Linux 0.11 원본 소스로 교체").
