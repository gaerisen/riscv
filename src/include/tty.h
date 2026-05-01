#ifndef TTY_H
#define TTY_H

#include "types.h"

void putc(char c);
int puts(const char *s, unsigned int len);

void putnum(u32 num);

char getc();
int gets(char *buf, unsigned int len);

#endif
