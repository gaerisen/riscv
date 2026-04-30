MEMORY
{
        FLASH (rx) : ORIGIN = 0x0000, LENGTH = 32K
        RAM (rwx) : ORIGIN = 0x8000, LENGTH = 16K
}

SECTIONS
{
        .text :
        {
                *(.text)
                *(.text.*)
                . = ALIGN(4);
        } > FLASH

        .rodata :
        {
                *(.rodata)
                *(.rodata.*)
                . = ALIGN(4);
        } > RAM

        .data :
        {
                *(.data)
                . = ALIGN(4);
        } > RAM

        .bss :
        {
                *(.bss)
                . = ALIGN(4);
        } > RAM

        PROVIDE(_heap_start = .);
}

ENTRY(_start)

PROVIDE(_stack_top = 0xc000);
PROVIDE(_stdout = 0xc00f);
PROVIDE(_stdin = 0xc00f);
