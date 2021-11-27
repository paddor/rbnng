/*
 * Copyright (c) 2021 Adib Saad
 *
 */
#include "msg.h"
#include "rbnng.h"
#include "socket.h"
#include <nng/protocol/pair1/pair.h>
#include <ruby.h>
#include <ruby/thread.h>

void*
pair1_get_msg_blocking(void* data)
{
  VALUE self = (VALUE)data;
  RbnngSocket* p_rbnngSocket;
  Data_Get_Struct(self, RbnngSocket, p_rbnngSocket);

  int rv;
  nng_msg* p_msg;
  if ((rv = nng_recvmsg(p_rbnngSocket->socket, &p_msg, 0)) != 0) {
    rb_raise(rbnng_exceptionClass, "nng_recvmsg %d", rv);
  }

  return p_msg;
}

static VALUE
socket_pair_get_msg(VALUE self)
{
  nng_msg* p_msg =
    rb_thread_call_without_gvl(pair1_get_msg_blocking, self, 0, 0);

  if (p_msg) {
    RbnngMsg* p_newMsg;
    VALUE newMsg = rb_class_new_instance(0, 0, rbnng_MsgClass);
    Data_Get_Struct(newMsg, RbnngMsg, p_newMsg);
    p_newMsg->msg = p_msg;
    return newMsg;
  } else {
    VALUE newMsg = rb_funcall(rbnng_MsgClass, rb_intern("new"), 0);
    return newMsg;
  }
}

void*
pair1_send_msg_blocking(void* data)
{
  RbnngSendMsgReq* p_sendMsgReq = (RbnngSendMsgReq*)data;
  RbnngSocket* p_rbnngSocket;
  Data_Get_Struct(p_sendMsgReq->socketObj, RbnngSocket, p_rbnngSocket);
  int rv;
  nng_msg* msg;
  if ((rv = nng_msg_alloc(&msg, 0)) != 0) {
    rb_raise(rbnng_exceptionClass, "nng_msg_alloc %d", rv);
  }

  nng_msg_append(msg,
                 StringValuePtr(p_sendMsgReq->nextMsg),
                 RSTRING_LEN(p_sendMsgReq->nextMsg));

  if ((rv = nng_sendmsg(p_rbnngSocket->socket, msg, 0)) != 0) {
    rb_raise(rbnng_exceptionClass, "nng_sendmsg %d", rv);
  }

  nng_msg_free(msg);

  return 0;
}

static VALUE
socket_pair_send_msg(VALUE self, VALUE rb_strMsg)
{
  Check_Type(rb_strMsg, T_STRING);
  RbnngSendMsgReq sendMsgReq = {
    .socketObj = self,
    .nextMsg   = rb_strMsg,
  };
  rb_thread_call_without_gvl(pair1_send_msg_blocking, &sendMsgReq, 0, 0);
}

static VALUE
socket_pair_dial(VALUE self, VALUE url)
{
  Check_Type(url, T_STRING);
  int rv;
  RbnngSocket* p_rbnngSocket;
  Data_Get_Struct(self, RbnngSocket, p_rbnngSocket);
  if ((rv = nng_dial(p_rbnngSocket->socket, StringValueCStr(url), NULL, 0)) !=
      0) {
    rb_raise(rbnng_exceptionClass, "nng_dial %d", rv);
  }
}

static VALUE
socket_pair_listen(VALUE self, VALUE url)
{
  Check_Type(url, T_STRING);
  int rv;
  RbnngSocket* p_rbnngSocket;
  Data_Get_Struct(self, RbnngSocket, p_rbnngSocket);
  if ((rv = nng_listen(p_rbnngSocket->socket, StringValueCStr(url), NULL, 0)) !=
      0) {
    rb_raise(rbnng_exceptionClass, "nng_listen %d", rv);
  }
}

static VALUE
socket_pair0_initialize(VALUE self)
{
  RbnngSocket* p_rbnngSocket;
  Data_Get_Struct(self, RbnngSocket, p_rbnngSocket);
  int rv;
  if ((rv = nng_pair0_open(&p_rbnngSocket->socket)) != 0) {
    rb_raise(rbnng_exceptionClass, "nng_pair1_open %d", rv);
  }
}

static VALUE
socket_pair1_initialize(VALUE self)
{
  RbnngSocket* p_rbnngSocket;
  Data_Get_Struct(self, RbnngSocket, p_rbnngSocket);
  int rv;
  if ((rv = nng_pair1_open(&p_rbnngSocket->socket)) != 0) {
    rb_raise(rbnng_exceptionClass, "nng_pair1_open %d", rv);
  }
}

void
rbnng_pair_Init(VALUE nng_module)
{
  VALUE rbnng_SocketModule = rb_define_module_under(nng_module, "Socket");

  VALUE rbnng_SocketPair1Class =
    rb_define_class_under(rbnng_SocketModule, "Pair1", rb_cObject);
  rb_define_alloc_func(rbnng_SocketPair1Class, socket_alloc);
  rb_define_method(
    rbnng_SocketPair1Class, "initialize", socket_pair1_initialize, 0);
  rb_define_method(rbnng_SocketPair1Class, "get_msg", socket_pair_get_msg, 0);
  rb_define_method(rbnng_SocketPair1Class, "send_msg", socket_pair_send_msg, 1);
  rb_define_method(rbnng_SocketPair1Class, "listen", socket_pair_listen, 1);
  rb_define_method(rbnng_SocketPair1Class, "dial", socket_pair_dial, 1);

  VALUE rbnng_SocketPair0Class =
    rb_define_class_under(rbnng_SocketModule, "Pair0", rb_cObject);
  rb_define_alloc_func(rbnng_SocketPair0Class, socket_alloc);
  rb_define_method(
    rbnng_SocketPair0Class, "initialize", socket_pair0_initialize, 0);
  rb_define_method(rbnng_SocketPair0Class, "get_msg", socket_pair_get_msg, 0);
  rb_define_method(rbnng_SocketPair0Class, "send_msg", socket_pair_send_msg, 1);
  rb_define_method(rbnng_SocketPair0Class, "listen", socket_pair_listen, 1);
  rb_define_method(rbnng_SocketPair0Class, "dial", socket_pair_dial, 1);
}
