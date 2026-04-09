/**
 * File: alias.S
 * Author: Garrison Taylor
 * Description: "Aliases" for common low-level operations to simplify C code
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
