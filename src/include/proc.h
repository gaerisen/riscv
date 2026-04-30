#ifndef PROC_H
#define PROC_H

#include "types.h"

typedef struct {
        u32 pc;
        u32 irf[31];
} proc;

#endif
