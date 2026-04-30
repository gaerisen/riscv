/**
 * File: start.S
 * Author: Garrison Taylor
 * Description: Entry point and interrupt vector
 *
 * Copyright (c) Garrison Taylor
 **/

.text
.globl _start

_start:
        nop

        li a0, 1
        slli a0, a0, 7
        csrw mstatus, a0

        la gp, _heap_start
        la sp, _stack_top
        la a0, _vec
        csrw mtvec, a0
        call main

_halt:
        j _halt

.globl _vec
_vec:
        addi sp, sp, -124

        sw x1, 120(sp)
        sw x2, 116(sp)
        sw x3, 112(sp)
        sw x4, 108(sp)
        sw x5, 104(sp)
        sw x6, 100(sp)
        sw x7, 96(sp)
        sw x8, 92(sp)
        sw x9, 88(sp)
        sw x10, 84(sp)
        sw x11, 80(sp)
        sw x12, 76(sp)
        sw x13, 72(sp)
        sw x14, 68(sp)
        sw x15, 64(sp)
        sw x16, 60(sp)
        sw x17, 56(sp)
        sw x18, 52(sp)
        sw x19, 48(sp)
        sw x20, 44(sp)
        sw x21, 40(sp)
        sw x22, 36(sp)
        sw x23, 32(sp)
        sw x24, 28(sp)
        sw x25, 24(sp)
        sw x26, 20(sp)
        sw x27, 16(sp)
        sw x28, 12(sp)
        sw x29, 8(sp)
        sw x30, 4(sp)
        sw x31, 0(sp)

        csrr a0, mcause
        mv a1, a7
        call handle_interrupt
        csrr a0, mepc
        addi a0, a0, 4
        csrw mepc, a0
        
        lw x1, 120(sp)
        lw x2, 116(sp)
        lw x3, 112(sp)
        lw x4, 108(sp)
        lw x5, 104(sp)
        lw x6, 100(sp)
        lw x7, 96(sp)
        lw x8, 92(sp)
        lw x9, 88(sp)
        lw x10, 84(sp)
        lw x11, 80(sp)
        lw x12, 76(sp)
        lw x13, 72(sp)
        lw x14, 68(sp)
        lw x15, 64(sp)
        lw x16, 60(sp)
        lw x17, 56(sp)
        lw x18, 52(sp)
        lw x19, 48(sp)
        lw x20, 44(sp)
        lw x21, 40(sp)
        lw x22, 36(sp)
        lw x23, 32(sp)
        lw x24, 28(sp)
        lw x25, 24(sp)
        lw x26, 20(sp)
        lw x27, 16(sp)
        lw x28, 12(sp)
        lw x29, 8(sp)
        lw x30, 4(sp)
        lw x31, 0(sp)

        addi sp, sp, 124

        mret
