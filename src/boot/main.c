#include "tty.h"
#include "sys.h"

int main()
{
        puts("RiscyOS v0.0.1", 16);
        return 0;
}

void handle_interrupt(int mcause, int callnum)
{
        if (mcause >> 31) { // Interrupt flag
                putc(getc());
        }
        return;
}
