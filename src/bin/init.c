#include "tty.h"
#include "sys.h"

void init()
{
        puts("Entered init(). Type whatever you want:\n\r", 41);
        enable_irq();
        while(1);
        return;
}
