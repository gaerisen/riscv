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

int strcmp(const char *s1, const char *s2, int n)
{
        u32 i, diff;
        for (i = 0; i < n; i++) {
                if (s1[i] == '\0' && s2[i] == '\0') break;

                diff = s1[i] - s2[i];
                if (diff != 0) {
                        return diff;
                }
        }

        return 0;
}
