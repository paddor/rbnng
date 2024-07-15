/*
 * Copyright (c) 2021 Adib Saad
 *
 */
#include <nng/nng.h>
#include <ruby.h>

#include "rbnng.h"
#include "exceptions.h"
#include "msg.h"
#include "sockets.h"

VALUE rbnng_Module = Qnil;

static VALUE
library_version(VALUE self_)
{
  return rb_ary_new3(3,
                     INT2NUM(NNG_MAJOR_VERSION),
                     INT2NUM(NNG_MINOR_VERSION),
                     INT2NUM(NNG_PATCH_VERSION));
}

void
Init_rbnng(void)
{
  rbnng_Module = rb_define_module("NNG");
  rb_define_singleton_method(rbnng_Module, "nng_version", library_version, 0);
  rbnng_exceptions_Init();
  rbnng_msg_Init();
  rbnng_sockets_Init();
}
