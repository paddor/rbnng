# Changelog

## Unreleased

### Breaking changes

- Rewritten C extension
- `raw` argument changed from positional bool to keyword (`raw: true`)
- `NNG::Socket::Base` moved to its own file (`lib/nng/socket/base.rb`)

### Added

- `Socket::Base#forward(msg)` — send an existing message preserving its header, enabling stateless raw mode proxying across multiple hops
- `Socket::Base#raw?` — check whether a socket was opened in raw mode
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
- Backward-compatible method aliases: `send_msg` -> `send`, `get_msg` -> `receive`
- `NNG.nng_version` — returns nng library version as a 3-element array via FFI
- pkg-config support in `extconf.rb` with fallback to system library path
- Benchmarks for throughput and latency (inproc and TCP)
- Specs for all socket protocols, raw mode proxy patterns, timeouts, memory management, and socket options

## 0.1.0

- Initial release with pair0/pair1, req0/rep0, pub0/sub0, push0/pull0, bus0, surveyor0/respondent0
- C extension using nng FFI bindings
