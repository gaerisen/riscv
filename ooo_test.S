.globl _start
_start:
        li a0, 0x10
        addi a1, a0, 0x1f
        andi t0, a1, 0x20
        or a0, a1, t0
        slli t0, a0, 4
        slli t1, a0, 8
        slli t2, a0, 16
        slli t3, a0, 24
        nop
        nop
        nop
        nop
        nop
        nop
halt:
        j halt
         
