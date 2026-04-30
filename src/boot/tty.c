#include "tty.h"

extern char _stdin;
extern char _stdout;

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
