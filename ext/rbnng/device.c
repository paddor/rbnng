#include "rbnng.h"

typedef struct {
    nng_socket s1;
    nng_socket s2;
    int        rv;
} device_args_t;

static void *
device_without_gvl(void *arg)
{
    device_args_t *a = arg;
    a->rv = nng_device(a->s1, a->s2);
    return NULL;
}

static VALUE
device_start(VALUE self, VALUE sock1, VALUE sock2)
{
    rbnng_socket_t *s1, *s2;
    TypedData_Get_Struct(sock1, rbnng_socket_t, &rbnng_socket_type, s1);
    TypedData_Get_Struct(sock2, rbnng_socket_t, &rbnng_socket_type, s2);

    if (!s1->initialized || !s2->initialized)
        rb_raise(rb_eRuntimeError, "socket not initialized");

    device_args_t args;
    args.s1 = s1->socket;
    args.s2 = s2->socket;

    rb_thread_call_without_gvl(device_without_gvl, &args, RUBY_UBF_IO, NULL);

    if (args.rv != 0)
        raise_nng_error(args.rv);
    return Qnil;
}

void
rbnng_device_init(VALUE nng_module)
{
    VALUE mod = rb_define_module_under(nng_module, "Device");
    rb_define_singleton_method(mod, "start", device_start, 2);
}
