#ifndef RBNNG_H
#define RBNNG_H

#include <nng/nng.h>
#include <ruby.h>
#include <ruby/thread.h>

/* ── Exceptions ─────────────────────────────────────────────────── */

void rbnng_exceptions_init(VALUE nng_module);
void raise_nng_error(int rv);

/* ── Message ────────────────────────────────────────────────────── */

typedef struct {
    nng_msg *msg; /* NULL when consumed */
} rbnng_msg_t;

extern const rb_data_type_t rbnng_msg_type;
extern VALUE cMessage;

VALUE rbnng_msg_wrap(nng_msg *msg);
void rbnng_msg_init(VALUE nng_module);

/* ── Socket ─────────────────────────────────────────────────────── */

typedef struct {
    nng_socket socket;
    int initialized;
} rbnng_socket_t;

extern const rb_data_type_t rbnng_socket_type;

void rbnng_socket_init(VALUE nng_module);

/* ── Device ─────────────────────────────────────────────────────── */

void rbnng_device_init(VALUE nng_module);

/* ── Pipe ──────────────────────────────────────────────────────── */

typedef struct {
    nng_pipe pipe;
} rbnng_pipe_t;

extern const rb_data_type_t rbnng_pipe_type;

VALUE rbnng_pipe_wrap(nng_pipe pipe);
void rbnng_pipe_init(VALUE nng_module);

/* ── TLS helpers (called from socket.c) ────────────────────────── */

void rbnng_tls_listen(nng_socket sock, const char *url,
                      VALUE cert_pem, VALUE key_pem, VALUE ca_pem,
                      int verify, VALUE server_name);

void rbnng_tls_dial(nng_socket sock, const char *url,
                    VALUE cert_pem, VALUE key_pem, VALUE ca_pem,
                    int verify, VALUE server_name);

#endif
