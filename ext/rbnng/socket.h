/*
 * Copyright (c) 2021 Adib Saad
 *
 */

#ifndef RBNNG_SOCKET_H
#define RBNNG_SOCKET_H

#include <nng/nng.h>
#include <ruby.h>
#include <stdbool.h>
#include <pthread.h>

typedef struct
{
  nng_socket socket;
  // Not all socket types will use a context
  nng_ctx ctx;
} RbnngSocket;

typedef struct {
  VALUE socketObj; // A socket class instnace
  VALUE nextMsg;   // Ruby string
} RbnngSendMsgReq;

extern void
rbnng_rep0_Init(VALUE nng_module);
extern void
rbnng_req0_Init(VALUE nng_module);
extern VALUE
socket_alloc(VALUE);

#endif
