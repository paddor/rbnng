# frozen_string_literal: true

require 'nng'
require 'async'
require 'benchmark/ips'

TRANSPORTS = {
  'inproc' => 'inproc://bench_latency',
  'ipc'    => 'ipc:///tmp/nng_bench_latency.sock',
  'tcp'    => 'tcp://127.0.0.1:9100',
}

puts "NNG #{NNG.nng_version.join('.')} | Ruby #{RUBY_VERSION}"
puts

payload = 'ping'

TRANSPORTS.each do |transport, addr|
  puts "--- #{transport} ---"

  Async do |task|
    req = NNG::Socket::Req0.new
    rep = NNG::Socket::Rep0.new
    rep.listen(addr)
    req.dial(addr)

    responder = task.async do
      loop do
        msg = rep.receive
        rep.send(msg.body)
      end
    end

    # Warm up
    100.times do
      req.send(payload)
      req.receive
    end

    Benchmark.ips do |x|
      x.config(warmup: 1, time: 3)

      x.report('roundtrip') do
        req.send(payload)
        req.receive
      end
    end

    responder.stop
  end

  puts
end
