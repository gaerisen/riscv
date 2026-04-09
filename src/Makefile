PREFIX = riscv32-unknown-elf-

CC = $(PREFIX)gcc
OBJCOPY = $(PREFIX)objcopy
OBJDUMP = $(PREFIX)objdump

LDSCRIPT = main.ld
CFLAGS = -march=rv32izicsr -mabi=ilp32 -ffreestanding -O0
ASFLAGS = $(CFLAGS)
LDFLAGS = -T $(LDSCRIPT) -nostdlib -nostartfiles -static

CSRC = main.c
ASMSRC = start.S alias.S
SRC = $(CSRC) $(ASMSRC)

OBJ = $(ASMSRC:%.S=%.o) $(CSRC:%.c=%.o)

TARGET = mem

all: flash.hex ram.hex
	cp $^ ../obj_dir/


$(OBJ): $(SRC)

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
	rm *.elf *.bin *.hex *.o
