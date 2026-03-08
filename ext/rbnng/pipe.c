#include "rbnng.h"

VALUE cPipe = Qnil;

/* ── Helpers ───────────────────────────────────────────────────── */

static inline nng_pipe
pipe_from_self(VALUE self)
{
    nng_pipe p;
    p.id = (uint32_t)NUM2UINT(rb_funcall(self, rb_intern("id"), 0));
    return p;
}

/* ── Methods ────────────────────────────────────────────────────── */

static VALUE
pipe_tls_verified_p(VALUE self)
{
    bool val;
    int rv = nng_pipe_get_bool(pipe_from_self(self), NNG_OPT_TLS_VERIFIED, &val);
    if (rv != 0)
        return Qfalse;
    return val ? Qtrue : Qfalse;
}

static VALUE
pipe_tls_peer_cn(VALUE self)
{
    char *val;
    int rv = nng_pipe_get_string(pipe_from_self(self), NNG_OPT_TLS_PEER_CN, &val);
    if (rv != 0)
        return Qnil;
    VALUE str = rb_str_new_cstr(val);
    nng_strfree(val);
    return str;
}

/* ── Init ───────────────────────────────────────────────────────── */

void
rbnng_pipe_init(VALUE nng_module)
{
    VALUE rb_cData = rb_path2class("Data");
    cPipe = rb_funcall(rb_cData, rb_intern("define"), 1, ID2SYM(rb_intern("id")));
    rb_set_class_path(cPipe, nng_module, "Pipe");
    rb_const_set(nng_module, rb_intern("Pipe"), cPipe);

    rb_define_method(cPipe, "tls_verified?", pipe_tls_verified_p, 0);
    rb_define_method(cPipe, "tls_peer_cn",   pipe_tls_peer_cn,    0);
}
