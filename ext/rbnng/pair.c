/*
 * Copyright (c) 2021 Adib Saad
 *
 */
#include "msg.h"
#include "rbnng.h"
#include "socket.h"
#include "sockets.h"
#include <nng/protocol/pair0/pair.h>
#include <nng/protocol/pair1/pair.h>
#include <ruby.h>
#include <ruby/thread.h>

static VALUE
socket_pair0_initialize(VALUE self)
{
  RbnngSocket* p_rbnngSocket;
  Data_Get_Struct(self, RbnngSocket, p_rbnngSocket);
  int rv;
  if ((rv = nng_pair0_open(&p_rbnngSocket->socket)) != 0) {
    raise_error(rv);
    return Qnil;
  }

  return self;
}

static VALUE
socket_pair1_initialize(VALUE self)
{
  RbnngSocket* p_rbnngSocket;
  Data_Get_Struct(self, RbnngSocket, p_rbnngSocket);
  int rv;
  if ((rv = nng_pair1_open(&p_rbnngSocket->socket)) != 0) {
    raise_error(rv);
    return Qnil;
  }

  return self;
}

void
rbnng_pair_Init(void)
{
  VALUE rbnng_SocketPair1Class =
    rb_define_class_under(rbnng_SocketModule, "Pair1", rbnng_SocketBaseClass);
  rb_define_alloc_func(rbnng_SocketPair1Class, socket_alloc);
  rb_define_method(
    rbnng_SocketPair1Class, "initialize", socket_pair1_initialize, 0);
  rb_define_method(rbnng_SocketPair1Class, "get_msg", socket_get_msg, 0);
  rb_define_method(rbnng_SocketPair1Class, "send_msg", socket_send_msg, 1);
  rb_define_method(rbnng_SocketPair1Class, "listen", socket_listen, 1);
  rb_define_method(rbnng_SocketPair1Class, "dial", socket_dial, 1);

  VALUE rbnng_SocketPair0Class =
    rb_define_class_under(rbnng_SocketModule, "Pair0", rbnng_SocketBaseClass);
  rb_define_alloc_func(rbnng_SocketPair0Class, socket_alloc);
  rb_define_method(
    rbnng_SocketPair0Class, "initialize", socket_pair0_initialize, 0);
  rb_define_method(rbnng_SocketPair0Class, "get_msg", socket_get_msg, 0);
  rb_define_method(rbnng_SocketPair0Class, "send_msg", socket_send_msg, 1);
  rb_define_method(rbnng_SocketPair0Class, "listen", socket_listen, 1);
  rb_define_method(rbnng_SocketPair0Class, "dial", socket_dial, 1);
}
