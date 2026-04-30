#ifndef TTY_H
#define TTY_H

void putc(char c);
int puts(const char *s, unsigned int len);
char getc();
int gets(char *buf, unsigned int len);

#endif
