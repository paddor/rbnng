/*
 * Copyright (c) 2021 Adib Saad
 *
 */

#include <nng/nng.h>
#include <ruby.h>

#include "msg.h"
#include "rbnng.h"
#include "socket.h"

VALUE rbnng_exceptionClass = Qnil;

static VALUE
library_version(VALUE self_)
{
  return rb_ary_new3(3,
                     INT2NUM(NNG_MAJOR_VERSION),
                     INT2NUM(NNG_MINOR_VERSION),
                     INT2NUM(NNG_PATCH_VERSION));
}

void
Init_rbnng()
{
  VALUE nng_module = rb_define_module("NNG");
  rb_define_singleton_method(nng_module, "nng_version", library_version, 0);
  rbnng_exceptionClass =
    rb_define_class_under(nng_module, "Error", rb_eRuntimeError);

  rbnng_msg_Init(nng_module);
  rbnng_rep0_Init(nng_module);
  rbnng_req0_Init(nng_module);
  rbnng_pair_Init(nng_module);
  rbnng_sub0_Init(nng_module);
  rbnng_pub0_Init(nng_module);
}
