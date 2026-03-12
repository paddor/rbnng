# rbnng

[![Gem Version](https://img.shields.io/gem/v/nng?color=e9573f)](https://rubygems.org/gems/nng)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Ruby](https://img.shields.io/badge/Ruby-%3E%3D%203.2-CC342D?logo=ruby&logoColor=white)](https://www.ruby-lang.org)

Fast, native Ruby bindings for [nng](https://nng.nanomsg.org/) — a lightweight, broker-less messaging library for building distributed systems.

> **37k+ msg/s** inproc throughput | **72 µs** fiber roundtrip latency | TLS built-in

---

## Highlights

- **All scalability protocols** — req/rep, pub/sub, push/pull, pair, survey, bus
- **Native C extension** — no FFI overhead, GVL released during blocking I/O
- **Async-first** — first-class [async](https://github.com/socketry/async) fiber support
- **Raw mode** — stateless proxying with `#forward`
- **TLS transport** — `tls+tcp://` with mTLS, certificate pinning, and peer introspection
- **Nonblock-first optimization** — tries `NNG_FLAG_NONBLOCK` before releasing the GVL for up to 26% higher throughput

## Install

Install nng on your system:

```sh
# macOS
brew install nng

# Debian/Ubuntu
apt install libnng-dev

# Arch
pacman -S nng
```

Then add the gem:

```sh
gem install nng
# or in Gemfile
gem 'nng'
```

<details>
<summary>TLS support (optional)</summary>

Install mbedTLS to enable the `tls+tcp://` transport:

```sh
# macOS
brew install mbedtls

# Debian/Ubuntu
apt install libmbedtls-dev

# Arch
pacman -S mbedtls
```

</details>

## Quick Start

### Request / Reply

```ruby
require 'nng'
require 'async'

Sync do |task|
  rep = NNG::Socket::Rep0.new
  rep.listen('tcp://127.0.0.1:5555')

  req = NNG::Socket::Req0.new
  req.dial('tcp://127.0.0.1:5555')

  task.async do
    msg = rep.receive
    rep.send("re: #{msg.body}")
  end

  req.send('hello')
  reply = req.receive
  puts reply.body  # => "re: hello"
end
```

### Pub / Sub

```ruby
Sync do |task|
  pub = NNG::Socket::Pub0.new
  pub.listen('ipc:///tmp/pubsub.sock')

  all = NNG::Socket::Sub0.new
  all.dial('ipc:///tmp/pubsub.sock')

  weather = NNG::Socket::Sub0.new(prefix: 'weather.')
  weather.dial('ipc:///tmp/pubsub.sock')

  sleep 0.01  # allow connections to establish

  task.async do
    pub.send('weather.rain')
    pub.send('sports.goal')
  end

  puts all.receive.body      # => "weather.rain"
  puts weather.receive.body  # => "weather.rain"
  puts all.receive.body      # => "sports.goal"
  # weather never receives "sports.goal"
end
```

### Push / Pull (Pipeline)

```ruby
Sync do |task|
  pull = NNG::Socket::Pull0.new
  pull.listen('inproc://pipeline')

  push = NNG::Socket::Push0.new
  push.dial('inproc://pipeline')

  task.async { push.send('work item') }
  puts pull.receive.body  # => "work item"
end
```

### Raw Mode Proxy

Raw mode sockets bypass the protocol state machine, enabling stateless message forwarding:

```ruby
Sync do |task|
  backend = NNG::Socket::Rep0.new
  backend.listen('inproc://backend')

  proxy_fe = NNG::Socket::Rep0.new(raw: true)
  proxy_fe.listen('inproc://frontend')

  proxy_be = NNG::Socket::Req0.new(raw: true)
  proxy_be.dial('inproc://backend')

  client = NNG::Socket::Req0.new
  client.dial('inproc://frontend')

  task.async do
    msg = backend.receive
    backend.send("processed: #{msg.body}")
  end

  task.async do
    msg = proxy_fe.receive
    proxy_be.forward(msg)
    reply = proxy_be.receive
    proxy_fe.forward(reply)
  end

  client.send('job')
  puts client.receive.body  # => "processed: job"
end
```

### TLS

Any socket type works over TLS — just use `tls+tcp://`:

```ruby
Sync do |task|
  rep = NNG::Socket::Rep0.new
  rep.listen('tls+tcp://127.0.0.1:5556',
             cert: server_cert, key: server_key)

  req = NNG::Socket::Req0.new
  req.dial('tls+tcp://127.0.0.1:5556',
           ca: ca_cert, server_name: 'myhost.example.com')

  task.async do
    msg = rep.receive
    rep.send("secure: #{msg.body}")
  end

  req.send('hello')
  puts req.receive.body  # => "secure: hello"
end
```

<details>
<summary>TLS option reference</summary>

**`#listen`**
| Option | Description |
|--------|-------------|
| `cert:` | Server certificate (PEM string, `OpenSSL::X509::Certificate`, or `Pathname`) |
| `key:` | Private key (PEM string, `OpenSSL::PKey`, or `Pathname`) |
| `ca:` | CA certificate for client verification (mutual TLS) |
| `verify:` | Require client certificates (`false` by default) |

**`#dial`**
| Option | Description |
|--------|-------------|
| `ca:` | CA certificate to verify the server |
| `cert:` / `key:` | Client certificate (for mutual TLS) |
| `server_name:` | Expected server CN/SAN (defaults to host from URL) |
| `verify: false` | Skip server certificate verification |

</details>

### Pipe Introspection

Received messages carry a pipe reference for connection-level metadata:

```ruby
msg = rep.receive
pipe = msg.pipe

pipe.tls_verified?  # => true
pipe.tls_peer_cn    # => "127.0.0.1"
pipe.id             # => 1
```

## Socket Options

```ruby
sock = NNG::Socket::Req0.new
sock.name = 'my-socket'
sock.recv_timeout = 1000          # milliseconds
sock.send_timeout = 1000
sock.recv_buffer = 128            # message count
sock.send_buffer = 128
sock.recv_max_size = 1048576      # bytes
sock.reconnect_time = 0.1..30.0  # seconds (min..max)

sock.raw?                         # => false
sock.protocol_name                # => "req"
sock.urls                         # => ["tcp://127.0.0.1:5555"]
```

## Protocols

| Protocol | Class | Direction |
|----------|-------|-----------|
| Pair v0 | `Pair0` | bidirectional |
| Pair v1 | `Pair1` | bidirectional |
| Request | `Req0` | send + receive |
| Reply | `Rep0` | receive + send |
| Publish | `Pub0` | send only |
| Subscribe | `Sub0` | receive only |
| Push | `Push0` | send only |
| Pull | `Pull0` | receive only |
| Survey | `Surveyor0` | send + receive |
| Respond | `Respondent0` | receive + send |
| Bus | `Bus0` | bidirectional |

All classes live under `NNG::Socket::` and support `raw: true` for raw mode.

## Transports

| Transport | URL scheme | Notes |
|-----------|-----------|-------|
| In-process | `inproc://` | Fastest, same process only |
| IPC | `ipc://` | Unix domain sockets |
| TCP | `tcp://` | TCP/IP |
| TLS | `tls+tcp://` | TCP + TLS encryption (requires mbedTLS) |

## Performance

Benchmarked with benchmark-ips on Linux x86_64 (NNG 1.10.0, Ruby 4.0.1):

#### Throughput (push/pull)

| | inproc | ipc | tcp |
|---|--------|-----|-----|
| **Async** | 32.7k/s | 10.3k/s | 8.7k/s |
| **Threads** | 37.8k/s | 17.7k/s | 7.2k/s |

#### Latency (req/rep roundtrip)

| | inproc | ipc | tcp |
|---|--------|-----|-----|
| **Async** | 72 µs | 172 µs | 280 µs |
| **Threads** | 198 µs | 231 µs | 273 µs |

Async fibers deliver 2.7x lower inproc latency thanks to cheap context switching. See [`bench/`](bench/) for full results and scripts.

## Development

```sh
bundle install
bundle exec rake compile
bundle exec rake test
```

## License

[MIT](LICENSE)
