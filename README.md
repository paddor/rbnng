# rbnng

Ruby bindings for [nng](https://nng.nanomsg.org/) (nanomsg next generation), a lightweight broker-less messaging library.

## Requirements

- Ruby >= 3.2
- libnng (with TLS support for `tls+tcp://`)

## Installation

Install nng on your system:

```sh
# macOS
brew install nng

# Debian/Ubuntu
apt install libnng-dev

# Arch
pacman -S nng
```

For TLS support (`tls+tcp://` transport), also install mbedTLS:

```sh
# macOS
brew install mbedtls

# Debian/Ubuntu
apt install libmbedtls-dev

# Arch
pacman -S mbedtls
```

Then install the gem:

```sh
gem install nng
```

Or add to your Gemfile:

```ruby
gem 'nng'
```

## Usage

### Request/Reply

```ruby
require 'nng'
require 'async'

Async do |task|
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

### Pub/Sub

```ruby
Async do |task|
  pub = NNG::Socket::Pub0.new
  pub.listen('ipc:///tmp/pubsub.sock')

  # Subscribe to everything (default)
  all = NNG::Socket::Sub0.new
  all.dial('ipc:///tmp/pubsub.sock')

  # Subscribe only to messages starting with "weather."
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

### Push/Pull (Pipeline)

```ruby
Async do |task|
  pull = NNG::Socket::Pull0.new
  pull.listen('inproc://pipeline')

  push = NNG::Socket::Push0.new
  push.dial('inproc://pipeline')

  task.async { push.send('work item') }
  msg = pull.receive
  puts msg.body  # => "work item"
end
```

### TLS

Any socket type works over TLS using `tls+tcp://` URLs:

```ruby
Async do |task|
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
  reply = req.receive
  puts reply.body  # => "secure: hello"
end
```

TLS options for `#listen`:
- `cert:` — server certificate (PEM string, OpenSSL::X509::Certificate, or Pathname)
- `key:` — private key (PEM string, OpenSSL::PKey, or Pathname)
- `ca:` — CA certificate for client verification (mutual TLS)
- `verify:` — require client certificates (`false` by default)

TLS options for `#dial`:
- `ca:` — CA certificate to verify the server
- `cert:` / `key:` — client certificate (for mutual TLS)
- `server_name:` — expected server CN/SAN (defaults to host from URL)
- `verify: false` — skip server certificate verification

### Pipe Introspection

Received messages carry a pipe reference for connection-level metadata:

```ruby
msg = rep.receive
pipe = msg.pipe

pipe.tls_verified?  # => true (peer certificate was verified)
pipe.tls_peer_cn    # => "127.0.0.1" (peer certificate CN)
pipe.id             # => 1 (pipe identifier)
```

### Raw Mode Proxy

Raw mode sockets bypass the protocol state machine, enabling stateless message forwarding. Headers stack and unstack automatically across hops:

```ruby
Async do |task|
  backend = NNG::Socket::Rep0.new
  backend.listen('inproc://backend')

  proxy_fe = NNG::Socket::Rep0.new(raw: true)
  proxy_fe.listen('inproc://frontend')

  proxy_be = NNG::Socket::Req0.new(raw: true)
  proxy_be.dial('inproc://backend')

  client = NNG::Socket::Req0.new
  client.dial('inproc://frontend')

  # Backend worker
  task.async do
    msg = backend.receive
    backend.send("processed: #{msg.body}")
  end

  # Stateless proxy — just forward messages
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
| Pair v0 | `NNG::Socket::Pair0` | bidirectional |
| Pair v1 | `NNG::Socket::Pair1` | bidirectional |
| Request | `NNG::Socket::Req0` | send + receive |
| Reply | `NNG::Socket::Rep0` | receive + send |
| Publish | `NNG::Socket::Pub0` | send only |
| Subscribe | `NNG::Socket::Sub0` | receive only |
| Push | `NNG::Socket::Push0` | send only |
| Pull | `NNG::Socket::Pull0` | receive only |
| Survey | `NNG::Socket::Surveyor0` | send + receive |
| Respond | `NNG::Socket::Respondent0` | receive + send |
| Bus | `NNG::Socket::Bus0` | bidirectional |

All protocols support `raw: true` for raw mode.

## Transports

- `inproc://` — in-process (fastest, same process only)
- `ipc://` — Unix domain sockets
- `tcp://` — TCP/IP
- `tls+tcp://` — TCP with TLS encryption

## Development

```sh
bundle install
bundle exec rake compile
bundle exec rake test
```

## License

MIT
