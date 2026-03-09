#include "rbnng.h"

/* ── Recursive stat tree → Ruby Hash ──────────────────────────── */

static VALUE unit_sym(int unit)
{
    switch (unit) {
    case NNG_UNIT_BYTES:    return ID2SYM(rb_intern("bytes"));
    case NNG_UNIT_MESSAGES: return ID2SYM(rb_intern("messages"));
    case NNG_UNIT_MILLIS:   return ID2SYM(rb_intern("millis"));
    case NNG_UNIT_EVENTS:   return ID2SYM(rb_intern("events"));
    default:                return Qnil;
    }
}

static VALUE stat_value(nng_stat *s)
{
    switch (nng_stat_type(s)) {
    case NNG_STAT_COUNTER:
    case NNG_STAT_LEVEL:
    case NNG_STAT_ID:
        return ULL2NUM(nng_stat_value(s));
    case NNG_STAT_STRING: {
        const char *v = nng_stat_string(s);
        return v ? rb_str_new_cstr(v) : Qnil;
    }
    case NNG_STAT_BOOLEAN:
        return nng_stat_bool(s) ? Qtrue : Qfalse;
    default:
        return Qnil;
    }
}

static VALUE stat_to_hash(nng_stat *s)
{
    VALUE hash = rb_hash_new();

    for (nng_stat *c = nng_stat_child(s); c; c = nng_stat_next(c)) {
        const char *name = nng_stat_name(c);
        VALUE key = ID2SYM(rb_intern(name));

        if (nng_stat_type(c) == NNG_STAT_SCOPE) {
            /* recurse into scopes */
            rb_hash_aset(hash, key, stat_to_hash(c));
        } else {
            /* leaf: {value:, desc:, unit:} or just value for simple cases */
            VALUE entry = rb_hash_new();
            rb_hash_aset(entry, ID2SYM(rb_intern("value")), stat_value(c));

            const char *desc = nng_stat_desc(c);
            if (desc && desc[0])
                rb_hash_aset(entry, ID2SYM(rb_intern("desc")), rb_str_new_cstr(desc));

            VALUE u = unit_sym(nng_stat_unit(c));
            if (!NIL_P(u))
                rb_hash_aset(entry, ID2SYM(rb_intern("unit")), u);

            rb_hash_aset(hash, key, entry);
        }
    }

    return hash;
}

/* ── NNG.stats → Hash ─────────────────────────────────────────── */

static VALUE
nng_rb_stats(VALUE self)
{
    nng_stat *root;
    int rv = nng_stats_get(&root);
    if (rv != 0)
        raise_nng_error(rv);

    VALUE result = stat_to_hash(root);
    nng_stats_free(root);
    return result;
}

/* ── NNG.stats_for(socket) → Hash ─────────────────────────────── */

static VALUE
nng_rb_stats_for(VALUE self, VALUE socket_obj)
{
    rbnng_socket_t *s;
    TypedData_Get_Struct(socket_obj, rbnng_socket_t, &rbnng_socket_type, s);

    nng_stat *root;
    int rv = nng_stats_get(&root);
    if (rv != 0)
        raise_nng_error(rv);

    nng_stat *ss = nng_stat_find_socket(root, s->socket);
    VALUE result = ss ? stat_to_hash(ss) : rb_hash_new();
    nng_stats_free(root);
    return result;
}

/* ── Init ──────────────────────────────────────────────────────── */

void
rbnng_stats_init(VALUE nng_module)
{
    rb_define_singleton_method(nng_module, "stats", nng_rb_stats, 0);
    rb_define_singleton_method(nng_module, "stats_for", nng_rb_stats_for, 1);
}
