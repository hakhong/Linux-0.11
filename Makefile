#
# if you want the ram-disk device, define this to be the
# size in blocks.
#
RAMDISK = #-DRAMDISK=512

AS86	=as86 -0 -a
LD86	=ld86 -0

AS	=as --32
LD	=ld -m elf_i386
LDFLAGS	=-Ttext 0 -e 0
CC	=gcc -m32 -g -fleading-underscore -fno-builtin -fno-stack-protector $(RAMDISK)
CFLAGS	=-Wall -O -fstrength-reduce -fomit-frame-pointer
CPP	=cpp -nostdinc -Iinclude

#
# ROOT_DEV specifies the default root-device when making the image.
# This can be either FLOPPY, /dev/xxxx or empty, in which case the
# default of /dev/hd6 is used by 'build'.
#
ROOT_DEV=/dev/hd1

ARCHIVES=kernel/kernel.o mm/mm.o fs/fs.o
DRIVERS =kernel/blk_drv/blk_drv.a kernel/chr_drv/chr_drv.a
MATH	=kernel/math/math.a
LIBS	=lib/lib.a

.c.s:
	$(CC) $(CFLAGS) \
	-nostdinc -Iinclude -S -o $*.s $<
.s.o:
	$(AS) -c -o $*.o $<
.c.o:
	$(CC) $(CFLAGS) \
	-nostdinc -Iinclude -c -o $*.o $<

all:	Image

Image: boot/bootsect boot/setup tools/kernel tools/build $(ROOT_DEV)
	tools/build boot/bootsect boot/setup tools/kernel $(ROOT_DEV) > Image
	sync

disk: Image
	dd bs=8192 if=Image of=/dev/PS0

# tools/build runs on the build host. It assumes a 32-bit host (long = 4
# bytes) whose <linux/fs.h> had MAJOR()/MINOR().
tools/build: tools/build.c
	gcc -m32 -O -include sys/sysmacros.h -DMAJOR=major -DMINOR=minor \
	-o tools/build tools/build.c

# build stat()s the root device node to get its major/minor numbers.
# The build container has none, so make it: /dev/hd1 = (3, 1).
/dev/hd1:
	mknod $@ b 3 1

# build expects 'system' to be an a.out file and skips its 1024-byte
# GCC header. tools/system is ELF (kept for gdb), so feed build the raw
# binary behind 1024 zero bytes instead.
tools/kernel: tools/system
	objcopy -O binary -R .note -R .comment tools/system tools/kernel.bin
	dd if=/dev/zero bs=1024 count=1 2>/dev/null | cat - tools/kernel.bin > tools/kernel
	rm -f tools/kernel.bin

boot/head.o: boot/head.s

tools/system:	boot/head.o init/main.o \
		$(ARCHIVES) $(DRIVERS) $(MATH) $(LIBS)
	$(LD) $(LDFLAGS) boot/head.o init/main.o \
	$(ARCHIVES) \
	$(DRIVERS) \
	$(MATH) \
	$(LIBS) \
	-o tools/system
	nm tools/system | grep -v '\(compiled\)\|\(\.o$$\)\|\( [aU] \)' | sort > System.map

kernel/math/math.a:
	(cd kernel/math; make)

kernel/blk_drv/blk_drv.a:
	(cd kernel/blk_drv; make)

kernel/chr_drv/chr_drv.a:
	(cd kernel/chr_drv; make)

kernel/kernel.o:
	(cd kernel; make)

mm/mm.o:
	(cd mm; make)

fs/fs.o:
	(cd fs; make)

lib/lib.a:
	(cd lib; make)

boot/setup: boot/setup.s
	$(AS86) -l boot/setup.lst -o boot/setup.o boot/setup.s
	$(LD86) -s -o boot/setup boot/setup.o

boot/bootsect:	boot/bootsect.s
	$(AS86) -l boot/bootsect.lst -o boot/bootsect.o boot/bootsect.s
	$(LD86) -s -o boot/bootsect boot/bootsect.o

tmp.s:	boot/bootsect.s tools/system
	(echo -n "SYSSIZE = (";ls -l tools/system | grep system \
		| cut -c25-31 | tr '\012' ' '; echo "+ 15 ) / 16") > tmp.s
	cat boot/bootsect.s >> tmp.s

clean:
	rm -f Image System.map tmp_make core boot/bootsect boot/setup boot/*.lst
	rm -f init/*.o tools/system tools/kernel tools/build boot/*.o
	(cd mm;make clean)
	(cd fs;make clean)
	(cd kernel;make clean)
	(cd lib;make clean)

backup: clean
	(cd .. ; tar cf - linux | compress - > backup.Z)
	sync

dep:
	sed '/\#\#\# Dependencies/q' < Makefile > tmp_make
	(for i in init/*.c;do echo -n "init/";$(CPP) -M $$i;done) >> tmp_make
	cp tmp_make Makefile
	(cd fs; make dep)
	(cd kernel; make dep)
	(cd mm; make dep)

### Dependencies:
init/main.o : init/main.c include/unistd.h include/sys/stat.h \
  include/sys/types.h include/sys/times.h include/sys/utsname.h \
  include/utime.h include/time.h include/linux/tty.h include/termios.h \
  include/linux/sched.h include/linux/head.h include/linux/fs.h \
  include/linux/mm.h include/signal.h include/asm/system.h include/asm/io.h \
  include/stddef.h include/stdarg.h include/fcntl.h 
