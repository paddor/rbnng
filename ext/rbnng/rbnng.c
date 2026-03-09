#include "rbnng.h"

static VALUE
library_version(VALUE self)
{
    return rb_ary_new3(3,
                       INT2NUM(NNG_MAJOR_VERSION),
                       INT2NUM(NNG_MINOR_VERSION),
                       INT2NUM(NNG_PATCH_VERSION));
}

void
Init_rbnng(void)
{
    VALUE nng = rb_define_module("NNG");
    rb_define_singleton_method(nng, "nng_version", library_version, 0);

    rbnng_exceptions_init(nng);
    rbnng_msg_init(nng);
    rbnng_pipe_init(nng);
    rbnng_socket_init(nng);
    rbnng_stats_init(nng);
    rbnng_device_init(nng);
}
