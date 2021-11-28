/*
 * Copyright (c) 2021 Adib Saad
 *
 */

#ifndef RBNNG_H
#define RBNNG_H

#include "exceptions.h"
#include <ruby.h>

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
extern void
rbnng_bus0_Init(VALUE nng_module);
extern void
rbnng_surveyor0_Init(VALUE nng_module);
extern void
rbnng_respondent0_Init(VALUE nng_module);

#endif
