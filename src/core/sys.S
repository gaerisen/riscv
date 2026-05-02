.globl spawn
spawn:
        li a7, 1
        ecall
        ret

.globl poll
poll:
        j poll
        ret

.globl exit
exit:
        li a7, 3
        ecall
        ret
