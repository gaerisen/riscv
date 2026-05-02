#ifndef SYS_H
#define SYS_H

extern void spawn(void (*entry)());
extern void poll(char *c);
extern void exit();

#endif
