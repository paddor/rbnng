/*
 * Copyright (c) 2021 Adib Saad
 *
 */
#include "msg.h"
#include "rbnng.h"
#include "socket.h"
#include "sockets.h"
#include <nng/protocol/survey0/survey.h>
#include <ruby.h>

static VALUE
socket_surveyor0_initialize(VALUE self)
{
  RbnngSocket* p_rbnngSocket;
  Data_Get_Struct(self, RbnngSocket, p_rbnngSocket);
  int rv;
  if ((rv = nng_surveyor0_open(&p_rbnngSocket->socket)) != 0) {
    raise_error(rv);
    return Qnil;
  }

  return self;
}

void
rbnng_surveyor0_Init(void)
{
  VALUE rbnng_SocketSurveyor0Class =
    rb_define_class_under(rbnng_SocketModule, "Surveyor0", rbnng_SocketBaseClass);
  rb_define_alloc_func(rbnng_SocketSurveyor0Class, socket_alloc);
  rb_define_method(
    rbnng_SocketSurveyor0Class, "initialize", socket_surveyor0_initialize, 0);
  rb_define_method(rbnng_SocketSurveyor0Class, "send_msg", socket_send_msg, 1);
  rb_define_method(rbnng_SocketSurveyor0Class, "get_msg", socket_get_msg, 0);
  rb_define_method(rbnng_SocketSurveyor0Class, "listen", socket_listen, 1);
}
