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
        sw x8, 96(sp)
        sw x10, 88(sp)

        csrr a0, mcause
        mv a1, a7
        call handle_interrupt
        csrr a0, mepc
        addi a0, a0, 4
        csrw mepc, a0
        
        lw x1, 124(sp)
        lw x2, 120(sp)
        lw x8, 96(sp)
        lw x10, 88(sp)

        addi sp, sp, 128

        mret
