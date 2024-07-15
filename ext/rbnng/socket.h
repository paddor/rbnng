/*
 * Copyright (c) 2021 Adib Saad
 *
 */

#ifndef RBNNG_SOCKET_H
#define RBNNG_SOCKET_H

#include <nng/nng.h>
#include <pthread.h>
#include <ruby.h>
#include <stdbool.h>

typedef struct
{
  nng_socket socket;
  // Not all socket types will use a context
  nng_ctx ctx;

  // for get_msg
  nng_msg* p_getMsgResult;
} RbnngSocket;

typedef struct
{
  VALUE socketObj; // A socket class instnace
  VALUE nextMsg;   // Ruby string
} RbnngSendMsgReq;

extern VALUE socket_alloc(VALUE);
extern VALUE socket_get_msg(VALUE);
extern VALUE socket_send_msg(VALUE, VALUE);
extern VALUE socket_dial(VALUE, VALUE);
extern VALUE socket_listen(VALUE, VALUE);
extern VALUE socket_get_opt_int(VALUE, VALUE);
extern VALUE socket_get_opt_ms(VALUE, VALUE);
extern VALUE socket_set_opt_ms(VALUE, VALUE, VALUE);

#endif
