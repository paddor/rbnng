/*
 * Copyright (c) 2021 Adib Saad
 *
 */
#include "msg.h"
#include "rbnng.h"
#include "socket.h"
#include "sockets.h"
#include <nng/protocol/pubsub0/pub.h>
#include <ruby.h>

static VALUE
socket_pub0_initialize(VALUE self)
{
  RbnngSocket* p_rbnngSocket;
  Data_Get_Struct(self, RbnngSocket, p_rbnngSocket);
  int rv;
  if ((rv = nng_pub0_open(&p_rbnngSocket->socket)) != 0) {
    raise_error(rv);
    return Qnil;
  }

  return self;
}

void
rbnng_pub0_Init(void)
{
  VALUE rbnng_SocketPub0Class =
    rb_define_class_under(rbnng_SocketModule, "Pub0", rbnng_SocketBaseClass);
  rb_define_alloc_func(rbnng_SocketPub0Class, socket_alloc);
  rb_define_method(
    rbnng_SocketPub0Class, "initialize", socket_pub0_initialize, 0);
  rb_define_method(rbnng_SocketPub0Class, "send_msg", socket_send_msg, 1);
  rb_define_method(rbnng_SocketPub0Class, "listen", socket_listen, 1);
}
