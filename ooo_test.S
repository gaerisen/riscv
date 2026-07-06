.globl _start
_start:
        li a0, 1
        li a1, 1
        bne a0, a1, halt
        nop
        nop
        nop
        beq a0, a1, halt
        nop
        nop
        nop
        nop
halt:
        j halt
