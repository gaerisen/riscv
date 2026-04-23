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
        li sp, 0x8020
        srai s0, sp, 3
        li a0, 0x43
        sw a0, 0(sp)
        lw a1, 4(sp)
        bgeu a1, a0, halt
        jalr s0
        nop

halt:
        j halt
