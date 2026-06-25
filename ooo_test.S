.globl _start
_start:
        li a0, 1
        li a1, 2
        li t0, 1000

fib_loop:
        add a2, a1, a0
        mv a0, a1
        mv a1, a2
        sw a2, 0(x0)
        blt a2, t0, fib_loop
        nop

        sw a1, 0(x0)
halt:
        j halt
         
