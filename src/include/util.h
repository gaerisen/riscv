#ifndef UTIL_H
#define UTIL_H

#include "types.h"

int strlen(const char *s);
void memcpy(u8 *from, u8 *to, u32 bytes);
void putnum(u32 num);
int strcmp(const char *s1, const char *s2, int n);

#endif
