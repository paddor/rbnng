/*
 * Copyright (c) 2021 Adib Saad
 *
 */
#include "rbnng.h"
#include "sockets.h"
#include "socket.h"
#include <ruby.h>
#include <ruby/thread.h>


VALUE rbnng_SocketModule = Qnil;
VALUE rbnng_SocketBaseClass = Qnil;

void
rbnng_sockets_Init(void)
{
  rbnng_SocketModule = rb_define_module_under(rbnng_Module, "Socket");
  rbnng_SocketBaseClass = rb_define_class_under(rbnng_SocketModule,
      "Base", rb_cObject);
  rb_define_method(rbnng_SocketBaseClass, "get_opt_int", socket_get_opt_int, 1);

  rbnng_rep0_Init();
  rbnng_req0_Init();
  rbnng_pub0_Init();
  rbnng_sub0_Init();
  rbnng_pair_Init();
  rbnng_bus0_Init();
  rbnng_surveyor0_Init();
  rbnng_respondent0_Init();
  rbnng_push0_Init();
  rbnng_pull0_Init();
}
