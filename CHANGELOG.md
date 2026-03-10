# Changelog

## 1.0.0.pre1

### Breaking changes

- Rewritten C extension from scratch
- `raw` argument changed from positional bool to keyword (`raw: true`)

### Added

- **TLS transport** — `tls+tcp://` URLs with `cert:`, `key:`, `ca:`, `verify:`, `server_name:` kwargs on `#listen` and `#dial`
- **Mutual TLS** — server-side client certificate verification
- **`NNG::Pipe`** — lightweight pipe introspection via `Message#pipe`
  - `#tls_verified?` — whether peer certificate was verified
  - `#tls_peer_cn` — peer certificate common name
  - `#id` — pipe identifier
- **`NNG::Device`** — transparent message forwarding between sockets
- **Pipe event notifications** — `Socket::Base#on_pipe_event` yields `:connect`/`:disconnect` events with `NNG::Pipe`
- **Runtime statistics** — `NNG.stats` and `NNG.stats_for(socket)` return NNG stat snapshots as nested Hashes
- **`Sub0#subscribe` / `Sub0#unsubscribe`** — add/remove topic subscriptions at runtime
- `Socket::Base#forward(msg)` — send an existing message preserving its header, enabling stateless raw mode proxying
- `Socket::Base#raw?` — check whether a socket was opened in raw mode
- `Sub0.new(prefix:)` — subscribe to a topic prefix at construction time
- Socket option accessors:
  - `name` / `name=` — socket name
  - `urls` — list of listen/dial URLs
  - `recv_buffer` / `recv_buffer=` — receive buffer size
  - `send_buffer` / `send_buffer=` — send buffer size
  - `recv_max_size` / `recv_max_size=` — max receive message size
  - `recv_timeout` / `recv_timeout=` — receive timeout (ms)
  - `send_timeout` / `send_timeout=` — send timeout (ms)
  - `reconnect_time` / `reconnect_time=` — reconnect interval as a `Range` of seconds
  - `protocol_name` / `peer_name` — read-only protocol info
- Generic option accessors: `get_opt_int`, `set_opt_int`, `get_opt_ms`, `set_opt_ms`, `get_opt_size`, `set_opt_size`, `get_opt_string`, `set_opt_string`
- `wait_readable` / `wait_writable` default to the socket's recv/send timeout
- `receive` / `send` raise `Timeout::Error` on timeout
- `NNG.nng_version` — returns nng library version as a 3-element array
- Message manipulation: `#body`, `#body_clear`, `#body_append`, `#header`, `#header=`, `#dup`, `#consumed?`
- pkg-config support in `extconf.rb` with fallback to system library path
- ZGuide messaging pattern examples (pipeline, lazy pirate, pub/sub, heartbeat, LVC, bstar, clone)
- Comprehensive specs for all protocols, TLS, raw mode, timeouts, memory management, and socket options
- Benchmarks for throughput and latency (inproc/IPC/TCP, async/threads)

## 0.1.0

- Initial release with pair0/pair1, req0/rep0, pub0/sub0, push0/pull0, bus0, surveyor0/respondent0
- C extension using nng FFI bindings
