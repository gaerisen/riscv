.globl _start

_start:
        la gp, _heap_start
        la sp, _stack_top
        call main

halt:
        j halt
        
