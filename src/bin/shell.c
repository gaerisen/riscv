#include "sys.h"
#include "tty.h"
#include "progs.h"
#include "util.h"

void getcmd(char *);
void exec(char *);

void shell()
{
        char buf[32];

        while (1) {
                puts("$ ", 2);
                getcmd(buf);
                exec(buf);
        }

        return;
}

void getcmd(char *buf)
{
        u32 i;
        for (i = 0; i < 32; i++) {
                poll(buf + i);
                if (buf[i] == 13) {
                        buf[i] = 0;
                        break;
                }
        }
        return;
}

void exec(char *buf)
{
        if (!strcmp(buf, "hi", 32)) spawn(&hi);
        else if (!strcmp(buf, "halt", 32)) exit();
        else puts("Invalid\n\r", 9);
        return;
}
