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
        li sp, 0x8000
        li a0, 0xdeadbeef
        li a1, 0x1000
        sb a0, 32(sp)
        add sp, sp, a1
        lw a0, 32(sp)
        sub sp, sp, a1
        lw a0, 32(sp)
        la sp, _stdout
        li a0, 'c'
        sb a0, 0(sp)

        li a0, 1
        slli a0, a0, 3
        csrw mstatus, a0
        slli a0, a0, 8
        csrw mie, a0

bruh:
        j bruh
        
        








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
