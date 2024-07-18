/*
 * Copyright (c) 2021 Adib Saad
 *
 */
#include "msg.h"
#include "rbnng.h"
#include "socket.h"
#include "sockets.h"
#include <nng/protocol/reqrep0/rep.h>
#include <ruby.h>
#include <ruby/thread.h>

static VALUE
socket_rep0_listen(VALUE self, VALUE url)
{
  Check_Type(url, T_STRING);
  int rv;
  RbnngSocket* p_rbnngSocket;
  Data_Get_Struct(self, RbnngSocket, p_rbnngSocket);
  if ((rv = nng_listen(p_rbnngSocket->socket, StringValueCStr(url), NULL, 0)) !=
      0) {
    raise_error(rv);
  }
}

void*
rep0_get_msg_blocking(RbnngSocket* p_rbnngSocket)
{
  nng_aio* p_aio;
  int rv;
  if ((rv = nng_aio_alloc(&p_aio, 0, 0)) != 0) {
    return (void*) rv;
  }

  nng_ctx_recv(p_rbnngSocket->ctx, p_aio);
  nng_aio_wait(p_aio);

  if ((rv = nng_aio_result(p_aio)) != 0) {
    return (void*) rv;
  }

  nng_msg* p_msg = nng_aio_get_msg(p_aio);
  p_rbnngSocket->p_getMsgResult = p_msg;
  nng_aio_free(p_aio);
  return 0;
}

static VALUE
socket_rep0_get_msg(VALUE self)
{
  RbnngSocket* p_rbnngSocket;
  Data_Get_Struct(self, RbnngSocket, p_rbnngSocket);
  int rv = (int) rb_thread_call_without_gvl(rep0_get_msg_blocking,
      p_rbnngSocket, 0, 0);

  if (rv == 0) {
    RbnngMsg* p_newMsg;
    VALUE newMsg = rb_class_new_instance(0, 0, rbnng_MsgClass);
    Data_Get_Struct(newMsg, RbnngMsg, p_newMsg);
    p_newMsg->p_msg = p_rbnngSocket->p_getMsgResult;
    return newMsg;
  } else {
    raise_error(rv);
    return Qnil;
  }
}

void*
rep0_send_msg_blocking(void* data)
{
  RbnngSendMsgReq* p_sendMsgReq = (RbnngSendMsgReq*)data;
  RbnngSocket* p_rbnngSocket;
  Data_Get_Struct(p_sendMsgReq->socketObj, RbnngSocket, p_rbnngSocket);

  nng_aio* p_aio;
  int rv;
  if ((rv = nng_aio_alloc(&p_aio, 0, 0)) != 0) {
    return (void*) rv;
  }

  nng_msg* p_msg;
  if ((rv = nng_msg_alloc(&p_msg, 0)) != 0) {
    return (void*) rv;
  }

  nng_msg_clear(p_msg);
  rv = nng_msg_append(p_msg,
                      StringValuePtr(p_sendMsgReq->nextMsg),
                      RSTRING_LEN(p_sendMsgReq->nextMsg));
  if (rv != 0) {
    return (void*) rv;
  }

  nng_aio_set_msg(p_aio, p_msg);
  nng_ctx_send(p_rbnngSocket->ctx, p_aio);
  nng_aio_wait(p_aio);

  if ((rv = nng_aio_result(p_aio)) != 0) {
    return (void*) rv;
  }

  nng_aio_free(p_aio);
  return 0;
}

static VALUE
socket_rep0_send_msg(VALUE self, VALUE rb_strMsg)
{
  Check_Type(rb_strMsg, T_STRING);

  RbnngSendMsgReq sendMsgReq = {
    .socketObj = self,
    .nextMsg = rb_strMsg,
  };
  int rv = (int) rb_thread_call_without_gvl(rep0_send_msg_blocking,
      &sendMsgReq, 0, 0);
  if (rv != 0) {
    raise_error(rv);
  }

  return Qnil;
}

static VALUE
socket_rep0_initialize(VALUE self)
{
  RbnngSocket* p_rbnngSocket;
  Data_Get_Struct(self, RbnngSocket, p_rbnngSocket);
  int rv;
  if ((rv = nng_rep0_open(&p_rbnngSocket->socket)) != 0) {
    raise_error(rv);
  }

  if ((rv = nng_ctx_open(&p_rbnngSocket->ctx, p_rbnngSocket->socket)) != 0) {
    raise_error(rv);
  }

  return self;
}

static VALUE
socket_rep0_initialize_raw(VALUE self)
{
  // TODO: initialize raw socket

  return self;
}

void
rbnng_rep0_Init(void)
{
  VALUE rbnng_SocketRep0Class =
    rb_define_class_under(rbnng_SocketModule, "Rep0", rbnng_SocketBaseClass);
  rb_define_alloc_func(rbnng_SocketRep0Class, socket_alloc);
  rb_define_method(
    rbnng_SocketRep0Class, "_initialize", socket_rep0_initialize, 0);
  rb_define_method(
    rbnng_SocketRep0Class, "_initialize_raw", socket_rep0_initialize_raw, 0);
  rb_define_method(rbnng_SocketRep0Class, "get_msg", socket_rep0_get_msg, 0);
  rb_define_method(rbnng_SocketRep0Class, "send_msg", socket_rep0_send_msg, 1);
  rb_define_method(rbnng_SocketRep0Class, "listen", socket_rep0_listen, 1);
}
