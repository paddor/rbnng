/*
 * Copyright (c) 2021 Adib Saad
 *
 */
#include "msg.h"
#include "rbnng.h"
#include "socket.h"
#include "sockets.h"
#include <nng/protocol/reqrep0/req.h>
#include <ruby.h>
#include <ruby/thread.h>

static VALUE
socket_req0_initialize(VALUE self)
{
  RbnngSocket* p_rbnngSocket;
  Data_Get_Struct(self, RbnngSocket, p_rbnngSocket);
  int rv;
  if ((rv = nng_req0_open(&p_rbnngSocket->socket)) != 0) {
    raise_error(rv);
    return Qnil;
  }

  return self;
}


static VALUE
socket_req0_initialize_raw(VALUE self)
{
  // TODO: initialize raw socket

  return self;
}

void
rbnng_req0_Init(void)
{
  VALUE rbnng_SocketReq0Class =
    rb_define_class_under(rbnng_SocketModule, "Req0", rbnng_SocketBaseClass);
  rb_define_alloc_func(rbnng_SocketReq0Class, socket_alloc);
  rb_define_method(
    rbnng_SocketReq0Class, "_initialize", socket_req0_initialize, 0);
  rb_define_method(
    rbnng_SocketReq0Class, "_initialize_raw", socket_req0_initialize_raw, 0);
  rb_define_method(rbnng_SocketReq0Class, "get_msg", socket_get_msg, 0);
  rb_define_method(rbnng_SocketReq0Class, "send_msg", socket_send_msg, 1);
  rb_define_method(rbnng_SocketReq0Class, "dial", socket_dial, 1);
}
