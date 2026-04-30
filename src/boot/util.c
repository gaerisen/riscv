#include "util.h"

int strlen(const char *s)
{
        unsigned int i = 0;

        while (s[i] != '\0') {
                i++;
        }

        return i;
}

void memcpy(u8 *from, u8 *to, u32 bytes)
{
        u32 i;
        for (i = 0; i < bytes; i++) {
                to[i] = from[i];
        }
        return;
}
