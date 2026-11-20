import gdb
import os
import re
import subprocess
import tempfile

# 보호모드(startup_32 이후)에서 불러올 심볼. 0x0 기준으로 링크되어 소스 줄 매핑이 된다.
SYMBOL_FILE = "tools/system"

# as86 -l 리스팅 파일 (2_build.sh 가 output/ 으로 복사한다)
LISTINGS = {
    "bootsect": ("output/bootsect.lst", "bootsect.s"),
    "setup": ("output/setup.lst", "setup.s"),
}

# as86 리스팅 한 줄: "00047 0000           B8                   07C0  \tmov\tax,#BOOTSEG"
# 줄번호(5자리) 오프셋(4자리) 다음 38칸이 기계어, 48번째 칸부터 소스다.
LST_RE = re.compile(r"^(\d{5}) ([0-9A-Fa-f]{4})(.{38})(.*)$")

_state = {"mode": None, "lst": {}}


def _load_listing(name):
    if name in _state["lst"]:
        return _state["lst"][name]
    table = {}
    path = LISTINGS[name][0]
    if os.path.exists(path):
        with open(path, encoding="utf-8", errors="replace") as f:
            for line in f:
                m = LST_RE.match(line.rstrip("\n"))
                if m and m.group(3).strip():
                    table.setdefault(int(m.group(2), 16), (int(m.group(1)), m.group(4).strip()))
    _state["lst"][name] = table
    return table


def _source_of(lin):
    """16비트 구간의 선형 주소 -> 'bootsect.s:47  mov ax,#BOOTSEG'. 모르면 None.

    bootsect 는 0x7c00 에서 시작해 0x90000 으로 옮겨지고, setup 은 0x90200 에 올라간다.
    둘 다 ORG 0 으로 어셈블되어 있어 (선형주소 - 로드 위치) 가 리스팅의 오프셋이다."""
    if 0x7c00 <= lin < 0x7e00:
        name, off = "bootsect", lin - 0x7c00
    elif 0x90000 <= lin < 0x90200:
        name, off = "bootsect", lin - 0x90000
    elif 0x90200 <= lin < 0x90200 + 0x800:
        name, off = "setup", lin - 0x90200
    else:
        return None
    hit = _load_listing(name).get(off)
    if hit is None:
        return None
    return "%s:%d  %s" % (LISTINGS[name][1], hit[0], hit[1])


def _cr0_pe():
    """CR0.PE 값. 읽을 수 없으면 None."""
    try:
        return bool(int(gdb.parse_and_eval("$cr0")) & 1)
    except (gdb.error, RuntimeError):
        pass
    try:
        out = gdb.execute("monitor info registers", to_string=True)
        m = re.search(r"CR0=([0-9a-fA-F]+)", out)
        if m:
            return bool(int(m.group(1), 16) & 1)
    except gdb.error:
        pass
    return None


def _protected_mode():
    """32비트 보호모드 코드를 실행 중이면 True. 판별 불가면 None.

    setup.s 는 'lmsw ax'(PE=1) 직후 'jmpi 0,8' 로 CS 를 갈아끼운다.
    그 사이 한두 명령은 PE=1 이지만 CS 가 아직 리얼모드 값(0x9020)이라 16비트다.
    그래서 PE=1 이면서 CS 가 GDT 셀렉터(작은 값)일 때만 보호모드로 본다."""
    pe = _cr0_pe()
    if pe is None:
        return None
    return pe and (int(gdb.parse_and_eval("$cs")) & 0xfff8) < 0x100


def _enter_mode(mode):
    """모드가 바뀐 순간에만 gdb 아키텍처/심볼을 맞춘다."""
    if _state["mode"] == mode:
        return
    if mode == "pm":
        gdb.execute("set architecture i386")
        src = os.getcwd()
        gdb.execute("set substitute-path /build %s" % src)
        gdb.execute("directory %s" % src)
        if os.path.exists(SYMBOL_FILE):
            gdb.execute("set confirm off")
            gdb.execute("symbol-file %s" % SYMBOL_FILE, to_string=True)
            gdb.execute("set confirm on")
            note = "32비트(i386) + %s 심볼" % SYMBOL_FILE
        else:
            note = "32비트(i386), %s 없음(심볼 로드 생략)" % SYMBOL_FILE
        print("[d16] 보호모드 감지 -> " + note)
    else:
        gdb.execute("set architecture i8086")
        if _state["mode"] is not None:
            print("[d16] 리얼모드 -> 16비트(i8086)")
    _state["mode"] = mode


class D16(gdb.Command):
    """d16 [N]: 현재 위치에서 N개 명령을 디스어셈블한다 (기본 5).

CR0.PE=1 이고 CS 가 GDT 셀렉터로 바뀌었을 때 보호모드로 판별한다.
  리얼모드(PE=0)  : cs:ip 의 바이트를 읽어 objdump -m i8086 으로 16비트 디스어셈블.
                    gdb 9.x 는 set architecture i8086 후에도 x/i 를 32비트로 해석하기 때문.
                    output/*.lst 가 있으면 소스 파일:줄도 함께 보여준다.
  보호모드(PE=1)  : i386 로 전환하고 tools/system 심볼을 로드한 뒤 기본 x/i 를 쓴다."""

    def __init__(self):
        super(D16, self).__init__("d16", gdb.COMMAND_DATA)

    def invoke(self, arg, from_tty):
        n = int(arg) if arg else 5
        pm = _protected_mode()
        if pm is None:
            print("[d16] CR0 를 읽을 수 없어 리얼모드로 가정")
            pm = False
        _enter_mode("pm" if pm else "rm")
        if pm:
            gdb.execute("x/%di $pc" % n)
        else:
            self.real_mode(n)

    def real_mode(self, n):
        cs = int(gdb.parse_and_eval("$cs"))
        ip = int(gdb.parse_and_eval("$eip")) & 0xffff
        lin = cs * 16 + ip
        data = bytes(gdb.selected_inferior().read_memory(lin, 16 * n))
        with tempfile.NamedTemporaryFile() as f:
            f.write(data)
            f.flush()
            out = subprocess.run(
                ["objdump", "-D", "-b", "binary", "-m", "i8086", "-M", "intel",
                 "--adjust-vma=%d" % lin, f.name],
                capture_output=True).stdout.decode()
        lines = [l for l in out.splitlines() if l.startswith(" ") and ":\t" in l]
        for i, l in enumerate(lines[:n]):
            print(("cs:ip=%04x:%04x " % (cs, ip) if i == 0 else " " * 17) + l)
        src = _source_of(lin)
        if src:
            print(" " * 17 + "; " + src)


D16()


class Regs(gdb.Command):
    """regs: 레지스터를 한눈에 본다. d16 과 같은 기준으로 모드를 고른다.

리얼모드(16비트 구간)  : ax bx cx dx si di bp sp, cs ds es ss, ip, flags (16비트로 자른 값)
보호모드(32비트 구간)  : eax..esp, cs ds es ss fs gs, eip, eflags (32비트 전체)
`info registers` 는 xmm/cr 까지 수십 줄이 나온다."""

    def __init__(self):
        super(Regs, self).__init__("regs", gdb.COMMAND_DATA)

    def invoke(self, arg, from_tty):
        def v(name):
            return int(gdb.parse_and_eval("$" + name)) & 0xffffffff

        if _protected_mode():
            print("eax=%08x ebx=%08x ecx=%08x edx=%08x" % (v("eax"), v("ebx"), v("ecx"), v("edx")))
            print("esi=%08x edi=%08x ebp=%08x esp=%08x" % (v("esi"), v("edi"), v("ebp"), v("esp")))
            print("cs=%04x ds=%04x es=%04x ss=%04x fs=%04x gs=%04x eip=%08x eflags=%08x" % (
                v("cs") & 0xffff, v("ds") & 0xffff, v("es") & 0xffff, v("ss") & 0xffff,
                v("fs") & 0xffff, v("gs") & 0xffff, v("eip"), v("eflags")))
        else:
            m = 0xffff
            print("ax=%04x bx=%04x cx=%04x dx=%04x si=%04x di=%04x bp=%04x sp=%04x" % (
                v("eax") & m, v("ebx") & m, v("ecx") & m, v("edx") & m,
                v("esi") & m, v("edi") & m, v("ebp") & m, v("esp") & m))
            print("cs=%04x ds=%04x es=%04x ss=%04x ip=%04x flags=%04x" % (
                v("cs") & m, v("ds") & m, v("es") & m, v("ss") & m, v("eip") & m, v("eflags") & m))


Regs()
