/*
 * Copyright (c) 2021 Adib Saad
 *
 */

#ifndef RBNNG_H
#define RBNNG_H

#include <ruby.h>

extern VALUE rbnng_exceptionClass;
extern void
rbnng_rep0_Init(VALUE nng_module);
extern void
rbnng_req0_Init(VALUE nng_module);
extern void
rbnng_pair_Init(VALUE nng_module);
extern void
rbnng_pub0_Init(VALUE nng_module);
extern void
rbnng_sub0_Init(VALUE nng_module);

#endif
