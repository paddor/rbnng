/*
 * Copyright (c) 2021 Adib Saad
 *
 */

#ifndef RBNNG_MSG_H
#define RBNNG_MSG_H

#include <nng/nng.h>
#include <ruby.h>

extern VALUE rbnng_MsgClass;

typedef struct
{
  nng_msg* msg;
} RbnngMsg;

extern void
rbnng_msg_Init(VALUE nng_module);

#endif
