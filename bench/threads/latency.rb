# frozen_string_literal: true

require 'nng'
require 'benchmark/ips'

TRANSPORTS = {
  'inproc' => 'inproc://bench_latency_t',
  'ipc'    => 'ipc:///tmp/nng_bench_latency_t.sock',
  'tcp'    => 'tcp://127.0.0.1:9200',
}

puts "NNG #{NNG.nng_version.join('.')} | Ruby #{RUBY_VERSION} (Threads)"
puts

payload = 'ping'

TRANSPORTS.each do |transport, addr|
  puts "--- #{transport} ---"

  req = NNG::Socket::Req0.new
  rep = NNG::Socket::Rep0.new
  rep.listen(addr)
  req.dial(addr)

  # Warm up
  100.times do
    Thread.new { rep.send(rep.receive.body) }
    req.send(payload)
    req.receive
  end

  Benchmark.ips do |x|
    x.config(warmup: 1, time: 3)

    x.report('roundtrip') do
      Thread.new { rep.send(rep.receive.body) }
      req.send(payload)
      req.receive
    end
  end

  puts
end
