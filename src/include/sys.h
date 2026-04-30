#ifndef SYS_H
#define SYS_H

#include "types.h"
#include "proc.h"

void ecall(u32 syscall_num);
void mret(proc *p);
void enable_irq();
void disable_irq();

#endif
