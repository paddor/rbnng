#include "rbnng.h"
#include <nng/supplemental/tls/tls.h>
#include <nng/transport/tls/tls.h>

/*
 * rbnng_tls_listen / rbnng_tls_dial — two-step listener/dialer with TLS config.
 *
 * Called from socket_listen_tls / socket_dial_tls in socket.c.
 * TLS kwargs are parsed in Ruby; C receives PEM strings directly.
 */

/* ── Helpers ───────────────────────────────────────────────────────── */

static nng_tls_config *
build_tls_config(nng_tls_mode mode, VALUE cert_pem, VALUE key_pem,
                 VALUE ca_pem, int verify, VALUE server_name)
{
    nng_tls_config *cfg;
    int rv = nng_tls_config_alloc(&cfg, mode);
    if (rv != 0)
        raise_nng_error(rv);

    /* Own certificate + key (server identity, or client mTLS) */
    if (!NIL_P(cert_pem) && !NIL_P(key_pem)) {
        rv = nng_tls_config_own_cert(cfg,
                                     StringValueCStr(cert_pem),
                                     StringValueCStr(key_pem),
                                     NULL);
        if (rv != 0) {
            nng_tls_config_free(cfg);
            raise_nng_error(rv);
        }
    }

    /* CA chain for peer verification */
    if (!NIL_P(ca_pem)) {
        rv = nng_tls_config_ca_chain(cfg, StringValueCStr(ca_pem), NULL);
        if (rv != 0) {
            nng_tls_config_free(cfg);
            raise_nng_error(rv);
        }
    }

    /* Auth mode */
    nng_tls_auth_mode auth = verify ? NNG_TLS_AUTH_MODE_REQUIRED
                                    : NNG_TLS_AUTH_MODE_NONE;
    rv = nng_tls_config_auth_mode(cfg, auth);
    if (rv != 0) {
        nng_tls_config_free(cfg);
        raise_nng_error(rv);
    }

    /* Server name (SNI / certificate matching) — client only */
    if (!NIL_P(server_name)) {
        rv = nng_tls_config_server_name(cfg, StringValueCStr(server_name));
        if (rv != 0) {
            nng_tls_config_free(cfg);
            raise_nng_error(rv);
        }
    }

    return cfg;
}

/* ── Public C API (called from socket.c) ──────────────────────────── */

void
rbnng_tls_listen(nng_socket sock, const char *url,
                 VALUE cert_pem, VALUE key_pem, VALUE ca_pem,
                 int verify, VALUE server_name)
{
    nng_tls_config *cfg = build_tls_config(NNG_TLS_MODE_SERVER,
                                           cert_pem, key_pem, ca_pem,
                                           verify, server_name);

    nng_listener listener;
    int rv = nng_listener_create(&listener, sock, url);
    if (rv != 0) {
        nng_tls_config_free(cfg);
        raise_nng_error(rv);
    }

    rv = nng_listener_set_ptr(listener, NNG_OPT_TLS_CONFIG, cfg);
    if (rv != 0) {
        nng_tls_config_free(cfg);
        raise_nng_error(rv);
    }

    rv = nng_listener_start(listener, 0);
    if (rv != 0) {
        nng_tls_config_free(cfg);
        raise_nng_error(rv);
    }

    nng_tls_config_free(cfg);
}

void
rbnng_tls_dial(nng_socket sock, const char *url,
               VALUE cert_pem, VALUE key_pem, VALUE ca_pem,
               int verify, VALUE server_name)
{
    nng_tls_config *cfg = build_tls_config(NNG_TLS_MODE_CLIENT,
                                           cert_pem, key_pem, ca_pem,
                                           verify, server_name);

    nng_dialer dialer;
    int rv = nng_dialer_create(&dialer, sock, url);
    if (rv != 0) {
        nng_tls_config_free(cfg);
        raise_nng_error(rv);
    }

    rv = nng_dialer_set_ptr(dialer, NNG_OPT_TLS_CONFIG, cfg);
    if (rv != 0) {
        nng_tls_config_free(cfg);
        raise_nng_error(rv);
    }

    rv = nng_dialer_start(dialer, 0);
    if (rv != 0) {
        nng_tls_config_free(cfg);
        raise_nng_error(rv);
    }

    nng_tls_config_free(cfg);
}
