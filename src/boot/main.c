#include "tty.h"
#include "sys.h"
#include "proc.h"
#include "bin/init.h"

u32 current_proc;

proc os_proc;
proc ptable[32];
u32 proc_mask = 0;

int main()
{
        puts("RiscyOS v0.0.1", 16);

        proc_mask = 1;

        current_proc = 0;
        ptable[0].pc = (u32)&init;

        __asm__ ("la sp, _heap_start");
        __asm__ ("addi sp, sp, 0x100");

        mret(ptable + 0);
        
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
