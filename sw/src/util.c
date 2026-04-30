#include "util.h"

int strlen(const char *s)
{
        unsigned int i = 0;

        while (s[i] != '\0') {
                i++;
        }

        return i;
}
