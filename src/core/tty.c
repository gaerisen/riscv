#include "tty.h"

extern char _stdin;
extern char _stdout;

const char hex_lut[16] = "0123456789abcdef";

void putc(char c)
{
        _stdout = c;
        return;
}

int puts(const char *s, unsigned int len)
{
        unsigned int i;

        for (i = 0; i < len; i++) {
                if (s[i] == '\0') return 1;
                _stdout = s[i];
        }

        return 0;
}

void putnum(u32 num)
{
        u32 tmp;
        puts("0x", 2);
        for (int i = 28; i >= 0; i -= 4) {
                tmp = num >> i;
                putc(hex_lut[tmp]);
                tmp <<= i;
                num -= tmp;
        }

        return;
}

char getc()
{
        return _stdin;
}

int gets(char *s, unsigned int len)
{
        unsigned int i;
        for (i = 0; i < len; i++) {
                s[i] = _stdin;
        }
        return 0;
}
