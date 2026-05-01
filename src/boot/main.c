#include "tty.h"
#include "types.h"
#include "sys.h"
#include "proc.h"
#include "bin/init.h"

extern u8 _heap_start;
extern u8 _kernel_end;

extern void _drop_into_userspace(proc *p);

u32 current_proc;

proc ptable[4];
u32 proc_mask = 0;

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

        proc_mask = 1;

        current_proc = 0;
        ptable[0].pc = (u32)&init;
        ptable[0].irf[1] = 0xa000 + 0x100;

        _drop_into_userspace(ptable);

        return 0;
}

proc *trap(int mcause, int callnum)
{
        if (mcause >> 31) { // Interrupt
                char c = getc();
                if (c == 13) {
                        putc('\n');
                        putc('\r');
                } else if (c == '~') {
                        puts("Got halt from init. Goodbye\n\r", 29);
                        while (1);
                } else {
                        putc(getc());
                }
        } else { // Exception
                switch (callnum) {
                default:
                        break;
                }
        }
        return &(ptable[current_proc]);
}
