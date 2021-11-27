/*
 * Copyright (c) 2021 Adib Saad
 *
 */
#include "socket.h"

static void
socket_free(void* ptr)
{
  RbnngSocket* p_rbnngSocket = (RbnngSocket*)ptr;
  nng_close(p_rbnngSocket->socket);
  xfree(p_rbnngSocket);
}

VALUE
socket_alloc(VALUE klass)
{
  RbnngSocket* p_rbnngSocket = ZALLOC(RbnngSocket);
  return rb_data_object_wrap(klass, p_rbnngSocket, 0, socket_free);
}
