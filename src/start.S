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
        la gp, _heap_start
        la sp, _stack_top
        la a0, _vec
        csrw mtvec, a0
        la a0, init
        csrw mepc, a0
        mret

.globl _vec
_vec:
        addi sp, sp, -128

        sw x1, 124(sp)
        sw x2, 120(sp)
        sw x3, 116(sp)
        sw x4, 112(sp)
        sw x5, 108(sp)
        sw x6, 104(sp)
        sw x7, 100(sp)
        sw x8, 96(sp)
        sw x9, 92(sp)
        sw x10, 88(sp)
        sw x11, 84(sp)
        sw x12, 80(sp)
        sw x13, 76(sp)
        sw x14, 72(sp)
        sw x15, 68(sp)
        sw x16, 64(sp)
        sw x17, 60(sp)
        sw x18, 56(sp)
        sw x19, 52(sp)
        sw x20, 48(sp)
        sw x21, 44(sp)
        sw x22, 40(sp)
        sw x23, 36(sp)
        sw x24, 32(sp)
        sw x25, 28(sp)
        sw x26, 24(sp)
        sw x27, 20(sp)
        sw x28, 16(sp)
        sw x29, 12(sp)
        sw x30, 8(sp)
        sw x31, 4(sp)

        csrr a0, mcause
        mv a1, a7
        call handle_interrupt
        csrr a0, mepc
        addi a0, a0, 4
        csrw mepc, a0
        
        lw x1, 124(sp)
        lw x2, 120(sp)
        lw x3, 116(sp)
        lw x4, 112(sp)
        lw x5, 108(sp)
        lw x6, 104(sp)
        lw x7, 100(sp)
        lw x8, 96(sp)
        lw x9, 92(sp)
        lw x10, 88(sp)
        lw x11, 84(sp)
        lw x12, 80(sp)
        lw x13, 76(sp)
        lw x14, 72(sp)
        lw x15, 68(sp)
        lw x16, 64(sp)
        lw x17, 60(sp)
        lw x18, 56(sp)
        lw x19, 52(sp)
        lw x20, 48(sp)
        lw x21, 44(sp)
        lw x22, 40(sp)
        lw x23, 36(sp)
        lw x24, 32(sp)
        lw x25, 28(sp)
        lw x26, 24(sp)
        lw x27, 20(sp)
        lw x28, 16(sp)
        lw x29, 12(sp)
        lw x30, 8(sp)
        lw x31, 4(sp)

        addi sp, sp, 128

        mret
