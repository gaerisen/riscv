#include "tty.h"
#include "sys.h"
#include "types.h"
#include "proc.h"
#include "bin/shell.h"

extern u8 _heap_start;
extern u8 _kernel_end;

extern void _drop_into_userspace(proc *p);

u32 current_proc;

proc ptable[8];

int main()
{
        u32 ktextsize = (u32)&_kernel_end;
        u32 kdatasize = (u32)(&_heap_start - 0x8000);

        puts(".text size: ", 12);
        putnum(ktextsize);
        puts("\n\r", 2);
        puts(".data size: ", 12);
        putnum(kdatasize);
        puts("\n\r", 2);

        current_proc = 0;
        ptable[0].pc = (u32)&shell;
        ptable[0].irf[1] = 0xa000;

        __asm__ ( "li t0, 1\n\t"
                  "slli t0, t0, 11\n\t"
                  "csrs mie, t0" );

        _drop_into_userspace(ptable);

        return 0;
}

void exec_syscall(int callnum, u32 *args)
{
        switch (callnum) {
        case 1:
                current_proc += 1;
                ptable[current_proc].pc = args[0];
                ptable[current_proc].irf[0] = (u32)(&exit);
                ptable[current_proc].irf[1] = 0xa000 + (current_proc << 8);
                break;
        case 3:
                if (current_proc == 0) {
                        puts("Shell exited. Goodbye\n\r", 23);
                        while(1);
                } else {
                        current_proc -= 1;
                        ptable[current_proc].pc += 4;
                }
                break;
        default:
                break;
        }
}

proc *trap(int mcause, int callnum, u32 *args)
{
        if (mcause >> 31) { // Interrupt
                char *buf = (char *)(args[0]);
                *buf = getc();
                if (*buf == 13) {
                        putc('\n');
                        putc('\r');
                } else {
                        putc(*buf);
                }
                ptable[current_proc].pc += 4;
        } else if (mcause == 11)  {
                exec_syscall(callnum, args);
        } else {
                puts("Unexpected exception. Goodbye\n\r", 31);
                while (1);
        }
        return ptable + current_proc;
}
