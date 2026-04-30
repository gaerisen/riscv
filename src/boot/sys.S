/**
 * File: sys.S
 * Author: Garrison Taylor
 * Description: Some common low-level system operations
 *
 * Copyright (c) Garrison Taylor
 **/

.globl ecall
ecall:
        addi sp, sp, -4
        lw a7, 0(sp)

        mv a7, a0
        ecall
        lw a7, 0(sp)

        addi sp, sp, 4
        ret

.globl enable_irq
enable_irq:
        addi sp, sp, -4
        sw a0, 0(sp)

        li a0, 1
        slli a0, a0, 11
        csrs mie, a0

        lw a0, 0(sp)
        addi sp, sp, 4
        ret

.globl disable_irq
disable_irq:
        addi sp, sp, -4
        sw a0, 0(sp)

        li a0, 1
        slli a0, a0, 11
        csrc mie, a0

        lw a0, 0(sp)
        addi sp, sp, 4
        ret
