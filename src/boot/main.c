#include "tty.h"
#include "types.h"
#include "sys.h"
#include "proc.h"
#include "bin/init.h"

extern u8 _heap_start;
extern u8 _kernel_end;

u32 current_proc;

proc ptable[32];
u32 proc_mask = 0;

int main()
{
        u32 ktextsize = (u32)&_kernel_end;
        u32 kdatasize = (u32)(&_heap_start - 0x8000);

        puts("Kernel size: ", 13);
        putnum(ktextsize);
        puts("\n\r", 2);
        puts(".data size: ", 12);
        putnum(kdatasize);
        puts("\n\r", 2);

        proc_mask = 1;

        current_proc = 0;
        ptable[0].pc = (u32)&init;

        return 0;
}

void trap(int mcause, int callnum)
{
        if (mcause >> 31) { // Interrupt
                char c = getc();
                if (c == 13) {
                        putc('\n');
                        putc('\r');
                } else {
                        putc(getc());
                }
        } else { // Exception
                switch (callnum) {
                default:
                        break;
                }
        }
        return;
}
