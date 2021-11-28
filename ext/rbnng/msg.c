/*
 * Copyright (c) 2021 Adib Saad
 *
 */
#include "msg.h"
#include <nng/protocol/reqrep0/rep.h>
#include <ruby.h>
#include <signal.h>

VALUE rbnng_MsgClass = Qnil;

void
msg_free(RbnngMsg* p_rbnngMsg)
{
  if (p_rbnngMsg->p_msg) {
    nng_msg_free(p_rbnngMsg->p_msg);
  }
  xfree(p_rbnngMsg);
}

static VALUE
msg_alloc(VALUE klass)
{
  RbnngMsg* p_rbnngMsg = ZALLOC(RbnngMsg);
  return rb_data_object_wrap(klass, p_rbnngMsg, 0, msg_free);
}

static VALUE
msg_body(VALUE self)
{
  RbnngMsg* p_rbnngMsg;
  Data_Get_Struct(self, RbnngMsg, p_rbnngMsg);
  if (p_rbnngMsg->p_msg) {
    return rb_str_new(nng_msg_body(p_rbnngMsg->p_msg),
                      nng_msg_len(p_rbnngMsg->p_msg));
  } else {
    return rb_str_new_cstr("");
  }
}

static VALUE
msg_header(VALUE self)
{
  RbnngMsg* p_rbnngMsg;
  Data_Get_Struct(self, RbnngMsg, p_rbnngMsg);
  if (p_rbnngMsg->p_msg) {
    return rb_str_new(nng_msg_header(p_rbnngMsg->p_msg),
                      nng_msg_header_len(p_rbnngMsg->p_msg));
  } else {
    return rb_str_new_cstr("");
  }
}

void
rbnng_msg_Init(VALUE nng_module)
{
  rbnng_MsgClass = rb_define_class_under(nng_module, "Msg", rb_cObject);
  rb_define_alloc_func(rbnng_MsgClass, msg_alloc);
  rb_define_method(rbnng_MsgClass, "body", msg_body, 0);
  rb_define_method(rbnng_MsgClass, "header", msg_header, 0);
}
