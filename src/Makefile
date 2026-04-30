ROOT = $(shell pwd)
INCDIR = $(ROOT)/include

PREFIX = riscv32-unknown-elf-

CC = $(PREFIX)gcc
OBJCOPY = $(PREFIX)objcopy
OBJDUMP = $(PREFIX)objdump

LDSCRIPT = main.ld
CFLAGS = -march=rv32izicsr -mabi=ilp32 -ffreestanding -O0 -I$(INCDIR)
ASFLAGS = $(CFLAGS)
LDFLAGS = -T $(LDSCRIPT) -nostdlib -nostartfiles -static

TARGET = boot

MODULES = $(shell find . -name Config.mk)

OBJ :=

include $(MODULES)

.PHONY: all clean cleaner $(SUBDIRS)

all: flash.hex ram.hex
	cp $^ ../obj_dir/

%.o: %.c
	$(CC) $(CFLAGS) -c $^ -o $@

%.o: %.S
	$(CC) $(ASFLAGS) -c $^ -o $@

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
	rm *.elf *.bin *.hex $(OBJ)
