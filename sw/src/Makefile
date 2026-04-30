CSRC = $(wildcard *.c)
ASMSRC = $(wildcard *.S)
SRC = $(CSRC) $(ASMSRC)

PREFIX = riscv32-unknown-elf-

CC = $(PREFIX)gcc
OBJCOPY = $(PREFIX)objcopy
OBJDUMP = $(PREFIX)objdump

LDSCRIPT = main.ld
CFLAGS = -march=rv32izicsr -mabi=ilp32 -ffreestanding -O0 -I$(INCDIR)
ASFLAGS = $(CFLAGS)
LDFLAGS = -T $(LDSCRIPT) -nostdlib -nostartfiles -static

OBJ = $(ASMSRC:%.S=%.o) $(CSRC:%.c=%.o)

all: $(OBJ)

$(OBJ): $(SRC)
