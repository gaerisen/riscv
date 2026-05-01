/**
 * File: start.S
 * Author: Garrison Taylor
 * Description: Entry point and interrupt vector
 *
 * Copyright (c) Garrison Taylor
 **/

.extern ptable
.extern current_proc

.text
.globl _start

_start:
        nop

        la sp, _kernel_end
        la sp, _heap_start
        la sp, _stack_top

        li a0, 1
        slli a0, a0, 3
        csrw mstatus, a0

        la gp, _heap_start
        mv sp, gp
        addi sp, sp, 0x400
        la a0, _vec
        csrw mtvec, a0
        call main

_halt:
        j _halt

.globl _vec
_vec:
        csrrw sp, mscratch, sp // Swap proc sp with kernel sp

        addi sp, sp, -8 // Store gp and a0
        sw gp, 0(sp)
        sw a0, 4(sp)

        la gp, ptable           // Load gp with the address of the proc struct
        la a0, current_proc     // corresponding to what we just trapped from
        lw a0, 0(a0)
        slli a0, a0, 8
        add gp, gp, a0

        sw ra, 4(gp)    // Store all regs in the chosen proc
        sw tp, 16(gp)
        sw t0, 20(gp)
        sw t1, 24(gp)
        sw t2, 28(gp)
        sw fp, 32(gp)
        sw s1, 36(gp)
        sw a1, 44(gp)
        sw a2, 48(gp)
        sw a3, 52(gp)
        sw a4, 56(gp)
        sw a5, 60(gp)
        sw a6, 64(gp)
        sw a7, 68(gp)
        sw s2, 72(gp)
        sw s3, 76(gp)
        sw s4, 80(gp)
        sw s5, 84(gp)
        sw s6, 88(gp)
        sw s7, 92(gp)
        sw s8, 96(gp)
        sw s9, 100(gp)
        sw s10, 104(gp)
        sw s11, 108(gp)
        sw t3, 112(gp)
        sw t4, 116(gp)
        sw t5, 120(gp)
        sw t6, 124(gp)

        csrr a0, mepc   // Store process pc
        addi a0, a0, 4
        sw a0, 0(gp)

        csrr a0, mscratch // Store process sp 
        sw a0, 8(gp)

        lw a0, 0(sp)    // Store the copies of gp and a0 we saved to stack
        sw a0, 12(gp)
        lw a0, 4(sp)
        sw a0, 40(gp)

        csrr a0, mcause // setup trap(int mcause, int syscall_num);
        mv a1, a7
        call trap // trap will return a ptr to the proc to drop into

        mv gp, a0

        lw a0, 0(gp) // Load process pc into mepc
        csrw mepc, a0

        addi sp, sp, 8  // Destroy the stack before state load
        csrw mscratch, sp // Scratch kernel sp

        lw ra, 4(gp)    // Load regs
        lw tp, 16(gp)
        lw t0, 20(gp)
        lw t1, 24(gp)
        lw t2, 28(gp)
        lw fp, 32(gp)
        lw s1, 36(gp)
        lw a0, 40(gp)
        lw a1, 44(gp)
        lw a2, 48(gp)
        lw a3, 52(gp)
        lw a4, 56(gp)
        lw a5, 60(gp)
        lw a6, 64(gp)
        lw a7, 68(gp)
        lw s2, 72(gp)
        lw s3, 76(gp)
        lw s4, 80(gp)
        lw s5, 84(gp)
        lw s6, 88(gp)
        lw s7, 92(gp)
        lw s8, 96(gp)
        lw s9, 100(gp)
        lw s10, 104(gp)
        lw s11, 108(gp)
        lw t3, 112(gp)
        lw t4, 116(gp)
        lw t5, 120(gp)
        lw t6, 124(gp)

        lw gp, 8(gp) // Load gp last

        mret
