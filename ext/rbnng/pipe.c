#include "rbnng.h"

VALUE cPipe = Qnil;

/* ── TypedData ──────────────────────────────────────────────────── */

static size_t
pipe_memsize(const void *ptr)
{
    return sizeof(rbnng_pipe_t);
}

const rb_data_type_t rbnng_pipe_type = {
    .wrap_struct_name = "NNG::Pipe",
    .function = {
        .dmark  = NULL,
        .dfree  = RUBY_DEFAULT_FREE,
        .dsize  = pipe_memsize,
    },
    .flags = RUBY_TYPED_FREE_IMMEDIATELY,
};

VALUE
rbnng_pipe_wrap(nng_pipe pipe)
{
    rbnng_pipe_t *p;
    VALUE obj = TypedData_Make_Struct(cPipe, rbnng_pipe_t, &rbnng_pipe_type, p);
    p->pipe = pipe;
    return obj;
}

static inline nng_pipe
pipe_get(VALUE self)
{
    rbnng_pipe_t *p;
    TypedData_Get_Struct(self, rbnng_pipe_t, &rbnng_pipe_type, p);
    return p->pipe;
}

/* ── Methods ────────────────────────────────────────────────────── */

static VALUE
pipe_id(VALUE self)
{
    return INT2NUM(nng_pipe_id(pipe_get(self)));
}

static VALUE
pipe_tls_verified_p(VALUE self)
{
    bool val;
    int rv = nng_pipe_get_bool(pipe_get(self), NNG_OPT_TLS_VERIFIED, &val);
    if (rv != 0)
        return Qfalse;
    return val ? Qtrue : Qfalse;
}

static VALUE
pipe_tls_peer_cn(VALUE self)
{
    char *val;
    int rv = nng_pipe_get_string(pipe_get(self), NNG_OPT_TLS_PEER_CN, &val);
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
    cPipe = rb_define_class_under(nng_module, "Pipe", rb_cObject);
    rb_undef_alloc_func(cPipe);

    rb_define_method(cPipe, "id",            pipe_id,             0);
    rb_define_method(cPipe, "tls_verified?", pipe_tls_verified_p, 0);
    rb_define_method(cPipe, "tls_peer_cn",   pipe_tls_peer_cn,    0);
}
