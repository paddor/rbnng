#include "rbnng.h"

#define HEADER_ELEMENT_SIZE 4

VALUE cMessage = Qnil;

/* ── TypedData ──────────────────────────────────────────────────── */

static void
msg_free(void *ptr)
{
    rbnng_msg_t *m = ptr;
    if (m->msg)
        nng_msg_free(m->msg);
    xfree(m);
}

static size_t
msg_memsize(const void *ptr)
{
    return sizeof(rbnng_msg_t);
}

const rb_data_type_t rbnng_msg_type = {
    .wrap_struct_name = "NNG::Message",
    .function = {
        .dmark  = NULL,
        .dfree  = msg_free,
        .dsize  = msg_memsize,
    },
    .flags = RUBY_TYPED_FREE_IMMEDIATELY,
};

static VALUE
msg_alloc(VALUE klass)
{
    rbnng_msg_t *m;
    return TypedData_Make_Struct(klass, rbnng_msg_t, &rbnng_msg_type, m);
}

VALUE
rbnng_msg_wrap(nng_msg *msg)
{
    VALUE obj = msg_alloc(cMessage);
    rbnng_msg_t *m;
    TypedData_Get_Struct(obj, rbnng_msg_t, &rbnng_msg_type, m);
    m->msg = msg;
    return obj;
}

static inline rbnng_msg_t *
msg_get(VALUE self)
{
    rbnng_msg_t *m;
    TypedData_Get_Struct(self, rbnng_msg_t, &rbnng_msg_type, m);
    return m;
}

static inline nng_msg *
msg_ptr(VALUE self)
{
    rbnng_msg_t *m = msg_get(self);
    if (!m->msg)
        rb_raise(rb_eRuntimeError, "message already consumed");
    return m->msg;
}

/* ── Methods ────────────────────────────────────────────────────── */

static VALUE
msg_body(VALUE self)
{
    nng_msg *p = msg_ptr(self);
    return rb_str_new(nng_msg_body(p), nng_msg_len(p));
}

static VALUE
msg_body_clear(VALUE self)
{
    nng_msg_clear(msg_ptr(self));
    return Qnil;
}

static VALUE
msg_body_append(VALUE self, VALUE data)
{
    nng_msg *p = msg_ptr(self);
    int rv = nng_msg_append(p, RSTRING_PTR(data), RSTRING_LEN(data));
    if (rv != 0)
        raise_nng_error(rv);
    return Qnil;
}

static VALUE
msg_header(VALUE self)
{
    nng_msg *p = msg_ptr(self);
    const char *data = nng_msg_header(p);
    size_t len = nng_msg_header_len(p);
    size_t count = len / HEADER_ELEMENT_SIZE;

    VALUE ary = rb_ary_new_capa((long)count);
    for (size_t i = 0; i < count; i++)
        rb_ary_push(ary, rb_str_new(data + i * HEADER_ELEMENT_SIZE,
                                    HEADER_ELEMENT_SIZE));
    return ary;
}

static VALUE
msg_set_header(VALUE self, VALUE elements)
{
    nng_msg *p = msg_ptr(self);
    Check_Type(elements, T_ARRAY);

    long count = RARRAY_LEN(elements);

    /* Validate all elements first */
    for (long i = 0; i < count; i++) {
        VALUE el = rb_ary_entry(elements, i);
        StringValue(el);
        if (RSTRING_LEN(el) != HEADER_ELEMENT_SIZE)
            rb_raise(rb_eArgError,
                     "header element must be exactly %d bytes, got %ld",
                     HEADER_ELEMENT_SIZE, RSTRING_LEN(el));
    }

    /* Clear and write */
    nng_msg_header_clear(p);
    for (long i = 0; i < count; i++) {
        VALUE el = rb_ary_entry(elements, i);
        int rv = nng_msg_header_append(p, RSTRING_PTR(el), RSTRING_LEN(el));
        if (rv != 0)
            raise_nng_error(rv);
    }

    return elements;
}

static VALUE
msg_dup(VALUE self)
{
    nng_msg *p = msg_ptr(self);
    nng_msg *copy;
    int rv = nng_msg_dup(&copy, p);
    if (rv != 0)
        raise_nng_error(rv);
    return rbnng_msg_wrap(copy);
}

static VALUE
msg_consumed_p(VALUE self)
{
    rbnng_msg_t *m = msg_get(self);
    return m->msg ? Qfalse : Qtrue;
}

/* ── Init ───────────────────────────────────────────────────────── */

void
rbnng_msg_init(VALUE nng_module)
{
    cMessage = rb_define_class_under(nng_module, "Message", rb_cObject);
    rb_define_alloc_func(cMessage, msg_alloc);

    rb_define_method(cMessage, "body",        msg_body,        0);
    rb_define_method(cMessage, "to_s",        msg_body,        0);
    rb_define_method(cMessage, "body_clear",  msg_body_clear,  0);
    rb_define_method(cMessage, "body_append", msg_body_append, 1);
    rb_define_method(cMessage, "header",      msg_header,      0);
    rb_define_method(cMessage, "header=",     msg_set_header,  1);
    rb_define_method(cMessage, "dup",         msg_dup,         0);
    rb_define_method(cMessage, "consumed?",   msg_consumed_p,  0);
}
