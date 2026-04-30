INCDIR = include

PREFIX = riscv32-unknown-elf-

CC = $(PREFIX)gcc
OBJCOPY = $(PREFIX)objcopy
OBJDUMP = $(PREFIX)objdump

LDSCRIPT = main.ld
CFLAGS = -march=rv32izicsr -mabi=ilp32 -ffreestanding -O0 -I$(INCDIR)
ASFLAGS = $(CFLAGS)
LDFLAGS = -T $(LDSCRIPT) -nostdlib -nostartfiles -static

TARGET = boot

export PREFIX
export CC
export CFLAGS
export ASFLAGS

SRCDIR = src/

.PHONY: all clean cleaner

$(SRCDIR): 
	$(MAKE) -C ^@

OBJ = $(shell find . -name '*.o')

all: flash.hex ram.hex
	cp $^ ../obj_dir/

$(OBJ): $(SUBDIRS)

$(TARGET).elf: $(OBJ)
	$(CC) $(LDFLAGS) $^ -o $@

$(TARGET).bin: $(TARGET).elf
	$(OBJCOPY) -O binary $^ $@

$(TARGET).hex: $(TARGET).bin
	od -An -vtx1 $^ > $@

flash.hex: $(TARGET).hex
	head -n 2048 $^ > $@

ram.hex: $(TARGET).hex
	tail -n +2049 $^ > $@

dump:
	$(OBJDUMP) -D $(TARGET).elf

clean:
	rm *.bin *.hex *.o
