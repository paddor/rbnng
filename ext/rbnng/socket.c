#include "rbnng.h"

#include <nng/protocol/bus0/bus.h>
#include <nng/protocol/pair0/pair.h>
#include <nng/protocol/pair1/pair.h>
#include <nng/protocol/pubsub0/pub.h>
#include <nng/protocol/pubsub0/sub.h>
#include <nng/protocol/pipeline0/pull.h>
#include <nng/protocol/pipeline0/push.h>
#include <nng/protocol/reqrep0/rep.h>
#include <nng/protocol/reqrep0/req.h>
#include <nng/protocol/survey0/respond.h>
#include <nng/protocol/survey0/survey.h>

/* ── TypedData ──────────────────────────────────────────────────── */

static void
socket_free(void *ptr)
{
    rbnng_socket_t *s = ptr;
    if (s->initialized)
        nng_close(s->socket);
    xfree(s);
}

static size_t
socket_memsize(const void *ptr)
{
    return sizeof(rbnng_socket_t);
}

const rb_data_type_t rbnng_socket_type = {
    .wrap_struct_name = "NNG::Socket::Base",
    .function = {
        .dmark  = NULL,
        .dfree  = socket_free,
        .dsize  = socket_memsize,
    },
    .flags = RUBY_TYPED_FREE_IMMEDIATELY,
};

static VALUE
socket_alloc(VALUE klass)
{
    rbnng_socket_t *s;
    return TypedData_Make_Struct(klass, rbnng_socket_t, &rbnng_socket_type, s);
}

static inline rbnng_socket_t *
socket_get(VALUE self)
{
    rbnng_socket_t *s;
    TypedData_Get_Struct(self, rbnng_socket_t, &rbnng_socket_type, s);
    if (!s->initialized)
        rb_raise(rb_eRuntimeError, "socket not initialized");
    return s;
}

/* ── GVL release helpers ────────────────────────────────────────── */

typedef struct {
    nng_socket socket;
    nng_msg   *msg;
    int        rv;
} recv_args_t;

static void *
recv_without_gvl(void *arg)
{
    recv_args_t *a = arg;
    a->msg = NULL;
    a->rv = nng_recvmsg(a->socket, &a->msg, 0);
    return NULL;
}

typedef struct {
    nng_socket  socket;
    nng_msg    *msg;
    int         rv;
} send_args_t;

static void *
send_without_gvl(void *arg)
{
    send_args_t *a = arg;
    a->rv = nng_sendmsg(a->socket, a->msg, 0);
    return NULL;
}

/* ── Shared methods (defined on Base) ───────────────────────────── */

static VALUE
socket_close(VALUE self)
{
    rbnng_socket_t *s = socket_get(self);
    int rv = nng_close(s->socket);
    if (rv != 0)
        raise_nng_error(rv);
    return Qnil;
}

static VALUE
socket_listen(VALUE self, VALUE url)
{
    rbnng_socket_t *s = socket_get(self);
    int rv = nng_listen(s->socket, StringValueCStr(url), NULL, 0);
    if (rv != 0)
        raise_nng_error(rv);
    return Qnil;
}

static VALUE
socket_dial(VALUE self, VALUE url)
{
    rbnng_socket_t *s = socket_get(self);
    int rv = nng_dial(s->socket, StringValueCStr(url), NULL, 0);
    if (rv != 0)
        raise_nng_error(rv);
    return Qnil;
}

static VALUE
socket_receive(VALUE self)
{
    rbnng_socket_t *s = socket_get(self);
    recv_args_t args;
    args.socket = s->socket;

    rb_thread_call_without_gvl(recv_without_gvl, &args, RUBY_UBF_IO, NULL);

    if (args.rv != 0)
        raise_nng_error(args.rv);
    return rbnng_msg_wrap(args.msg);
}

static VALUE
socket_send(VALUE self, VALUE data)
{
    rbnng_socket_t *s = socket_get(self);
    StringValue(data);

    nng_msg *msg;
    int rv = nng_msg_alloc(&msg, 0);
    if (rv != 0)
        raise_nng_error(rv);

    rv = nng_msg_append(msg, RSTRING_PTR(data), RSTRING_LEN(data));
    if (rv != 0) {
        nng_msg_free(msg);
        raise_nng_error(rv);
    }

    send_args_t args;
    args.socket = s->socket;
    args.msg = msg;

    rb_thread_call_without_gvl(send_without_gvl, &args, RUBY_UBF_IO, NULL);

    if (args.rv != 0) {
        nng_msg_free(msg);
        raise_nng_error(args.rv);
    }
    return Qnil;
}

static VALUE
socket_forward(VALUE self, VALUE msg_obj)
{
    rbnng_socket_t *s = socket_get(self);
    rbnng_msg_t *m;
    TypedData_Get_Struct(msg_obj, rbnng_msg_t, &rbnng_msg_type, m);

    if (!m->msg)
        rb_raise(rb_eRuntimeError, "message already consumed");

    nng_msg *raw_msg = m->msg;
    m->msg = NULL; /* consume */

    send_args_t args;
    args.socket = s->socket;
    args.msg = raw_msg;

    rb_thread_call_without_gvl(send_without_gvl, &args, RUBY_UBF_IO, NULL);

    if (args.rv != 0) {
        nng_msg_free(raw_msg);
        raise_nng_error(args.rv);
    }
    return Qnil;
}

static VALUE
socket_recv_fd(VALUE self)
{
    rbnng_socket_t *s = socket_get(self);
    int fd;
    int rv = nng_socket_get_int(s->socket, NNG_OPT_RECVFD, &fd);
    if (rv != 0)
        raise_nng_error(rv);
    return INT2FIX(fd);
}

static VALUE
socket_send_fd(VALUE self)
{
    rbnng_socket_t *s = socket_get(self);
    int fd;
    int rv = nng_socket_get_int(s->socket, NNG_OPT_SENDFD, &fd);
    if (rv != 0)
        raise_nng_error(rv);
    return INT2FIX(fd);
}

/* ── Option getters/setters ─────────────────────────────────────── */

static VALUE
socket_get_opt_int(VALUE self, VALUE name)
{
    rbnng_socket_t *s = socket_get(self);
    int val;
    int rv = nng_socket_get_int(s->socket, StringValueCStr(name), &val);
    if (rv != 0)
        raise_nng_error(rv);
    return INT2NUM(val);
}

static VALUE
socket_set_opt_int(VALUE self, VALUE name, VALUE val)
{
    rbnng_socket_t *s = socket_get(self);
    int rv = nng_socket_set_int(s->socket, StringValueCStr(name), NUM2INT(val));
    if (rv != 0)
        raise_nng_error(rv);
    return Qnil;
}

static VALUE
socket_get_opt_ms(VALUE self, VALUE name)
{
    rbnng_socket_t *s = socket_get(self);
    nng_duration val;
    int rv = nng_socket_get_ms(s->socket, StringValueCStr(name), &val);
    if (rv != 0)
        raise_nng_error(rv);
    return INT2NUM(val);
}

static VALUE
socket_set_opt_ms(VALUE self, VALUE name, VALUE val)
{
    rbnng_socket_t *s = socket_get(self);
    int rv = nng_socket_set_ms(s->socket, StringValueCStr(name), NUM2INT(val));
    if (rv != 0)
        raise_nng_error(rv);
    return Qnil;
}

static VALUE
socket_get_opt_size(VALUE self, VALUE name)
{
    rbnng_socket_t *s = socket_get(self);
    size_t val;
    int rv = nng_socket_get_size(s->socket, StringValueCStr(name), &val);
    if (rv != 0)
        raise_nng_error(rv);
    return SIZET2NUM(val);
}

static VALUE
socket_set_opt_size(VALUE self, VALUE name, VALUE val)
{
    rbnng_socket_t *s = socket_get(self);
    int rv = nng_socket_set_size(s->socket, StringValueCStr(name), NUM2SIZET(val));
    if (rv != 0)
        raise_nng_error(rv);
    return Qnil;
}

static VALUE
socket_get_opt_string(VALUE self, VALUE name)
{
    rbnng_socket_t *s = socket_get(self);
    char *val;
    int rv = nng_socket_get_string(s->socket, StringValueCStr(name), &val);
    if (rv != 0)
        raise_nng_error(rv);
    VALUE str = rb_str_new_cstr(val);
    nng_strfree(val);
    return str;
}

static VALUE
socket_set_opt_string(VALUE self, VALUE name, VALUE val)
{
    rbnng_socket_t *s = socket_get(self);
    int rv = nng_socket_set_string(s->socket, StringValueCStr(name),
                                   StringValueCStr(val));
    if (rv != 0)
        raise_nng_error(rv);
    return Qnil;
}

/* ── Protocol initializers ──────────────────────────────────────── */

static int
parse_raw_kwarg(int argc, VALUE *argv)
{
    VALUE opts = Qnil;
    rb_scan_args(argc, argv, ":", &opts);
    if (NIL_P(opts))
        return 0;
    VALUE raw = rb_hash_lookup2(opts, ID2SYM(rb_intern("raw")), Qfalse);
    return RTEST(raw);
}

#define DEF_INIT(name, open_fn, open_raw_fn)                          \
    static VALUE                                                      \
    name(int argc, VALUE *argv, VALUE self)                           \
    {                                                                 \
        rbnng_socket_t *s;                                            \
        TypedData_Get_Struct(self, rbnng_socket_t,                    \
                             &rbnng_socket_type, s);                  \
        if (s->initialized)                                           \
            rb_raise(rb_eRuntimeError, "socket already initialized"); \
        int raw = parse_raw_kwarg(argc, argv);                        \
        int rv = raw ? open_raw_fn(&s->socket)                        \
                     : open_fn(&s->socket);                           \
        if (rv != 0)                                                  \
            raise_nng_error(rv);                                      \
        s->initialized = 1;                                           \
        rb_ivar_set(self, rb_intern("@raw"), raw ? Qtrue : Qfalse);   \
        return self;                                                  \
    }

DEF_INIT(pair0_init,      nng_pair0_open,      nng_pair0_open_raw)
DEF_INIT(pair1_init,      nng_pair1_open,      nng_pair1_open_raw)
DEF_INIT(bus0_init_inner, nng_bus0_open,        nng_bus0_open_raw)
DEF_INIT(pub0_init,       nng_pub0_open,        nng_pub0_open_raw)
DEF_INIT(sub0_init_inner, nng_sub0_open,        nng_sub0_open_raw)
DEF_INIT(push0_init,      nng_push0_open,       nng_push0_open_raw)
DEF_INIT(pull0_init,      nng_pull0_open,       nng_pull0_open_raw)
DEF_INIT(req0_init,       nng_req0_open,        nng_req0_open_raw)
DEF_INIT(rep0_init,       nng_rep0_open,        nng_rep0_open_raw)
DEF_INIT(surveyor0_init,  nng_surveyor0_open,   nng_surveyor0_open_raw)
DEF_INIT(respondent0_init,nng_respondent0_open, nng_respondent0_open_raw)

/* Sub0: subscribe with optional prefix: kwarg (default: all) */
static VALUE
sub0_init(int argc, VALUE *argv, VALUE self)
{
    rbnng_socket_t *s;
    TypedData_Get_Struct(self, rbnng_socket_t, &rbnng_socket_type, s);
    if (s->initialized)
        rb_raise(rb_eRuntimeError, "socket already initialized");

    VALUE opts = Qnil;
    rb_scan_args(argc, argv, ":", &opts);

    int raw = 0;
    VALUE prefix = Qnil;
    if (!NIL_P(opts)) {
        raw = RTEST(rb_hash_lookup2(opts, ID2SYM(rb_intern("raw")), Qfalse));
        prefix = rb_hash_lookup2(opts, ID2SYM(rb_intern("prefix")), Qnil);
    }

    int rv = raw ? nng_sub0_open_raw(&s->socket)
                 : nng_sub0_open(&s->socket);
    if (rv != 0)
        raise_nng_error(rv);
    s->initialized = 1;
    rb_ivar_set(self, rb_intern("@raw"), raw ? Qtrue : Qfalse);

    if (NIL_P(prefix)) {
        rv = nng_socket_set(s->socket, NNG_OPT_SUB_SUBSCRIBE, NULL, 0);
    } else {
        StringValue(prefix);
        rv = nng_socket_set(s->socket, NNG_OPT_SUB_SUBSCRIBE,
                            RSTRING_PTR(prefix), RSTRING_LEN(prefix));
    }
    if (rv != 0)
        raise_nng_error(rv);

    return self;
}

/* Bus0: set default recv timeout */
static VALUE
bus0_init(int argc, VALUE *argv, VALUE self)
{
    bus0_init_inner(argc, argv, self);
    rbnng_socket_t *s = socket_get(self);
    int rv = nng_socket_set_ms(s->socket, NNG_OPT_RECVTIMEO, 100);
    if (rv != 0)
        raise_nng_error(rv);
    return self;
}

/* ── Ruby class registration ───────────────────────────────────── */

#define REG_PROTO(mod, name, init_fn)                                 \
    do {                                                              \
        VALUE cls = rb_define_class_under(mod, name, base);           \
        rb_define_method(cls, "initialize", init_fn, -1);             \
    } while (0)

void
rbnng_socket_init(VALUE nng_module)
{
    VALUE mod = rb_define_module_under(nng_module, "Socket");

    VALUE base = rb_define_class_under(mod, "Base", rb_cObject);
    rb_define_alloc_func(base, socket_alloc);

    rb_define_method(base, "close",          socket_close,          0);
    rb_define_method(base, "listen",         socket_listen,         1);
    rb_define_method(base, "dial",           socket_dial,           1);
    rb_define_method(base, "receive",        socket_receive,        0);
    rb_define_method(base, "send",           socket_send,           1);
    rb_define_method(base, "forward",        socket_forward,        1);
    rb_define_method(base, "recv_fd",        socket_recv_fd,        0);
    rb_define_method(base, "send_fd",        socket_send_fd,        0);
    rb_define_method(base, "get_opt_int",    socket_get_opt_int,    1);
    rb_define_method(base, "set_opt_int",    socket_set_opt_int,    2);
    rb_define_method(base, "get_opt_ms",     socket_get_opt_ms,     1);
    rb_define_method(base, "set_opt_ms",     socket_set_opt_ms,     2);
    rb_define_method(base, "get_opt_size",   socket_get_opt_size,   1);
    rb_define_method(base, "set_opt_size",   socket_set_opt_size,   2);
    rb_define_method(base, "get_opt_string", socket_get_opt_string, 1);
    rb_define_method(base, "set_opt_string", socket_set_opt_string, 2);

    REG_PROTO(mod, "Pair0",       pair0_init);
    REG_PROTO(mod, "Pair1",       pair1_init);
    REG_PROTO(mod, "Bus0",        bus0_init);
    REG_PROTO(mod, "Pub0",        pub0_init);
    REG_PROTO(mod, "Sub0",        sub0_init);
    REG_PROTO(mod, "Push0",       push0_init);
    REG_PROTO(mod, "Pull0",       pull0_init);
    REG_PROTO(mod, "Req0",        req0_init);
    REG_PROTO(mod, "Rep0",        rep0_init);
    REG_PROTO(mod, "Surveyor0",   surveyor0_init);
    REG_PROTO(mod, "Respondent0", respondent0_init);
}
