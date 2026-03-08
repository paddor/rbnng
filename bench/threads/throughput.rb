# frozen_string_literal: true

require 'nng'
require 'benchmark/ips'

MSG_SIZES = [64, 256, 1024, 4096]
TRANSPORTS = {
  'inproc' => ->(tag) { "inproc://bench_tp_t_#{tag}" },
  'ipc'    => ->(tag) { "ipc:///tmp/nng_bench_tp_t_#{tag}.sock" },
  'tcp'    => ->(tag) { "tcp://127.0.0.1:#{9000 + tag.hash.abs % 1000}" },
}

puts "NNG #{NNG.nng_version.join('.')} | Ruby #{RUBY_VERSION} (Threads)"
puts

TRANSPORTS.each do |transport, addr_fn|
  puts "--- #{transport} ---"

  MSG_SIZES.each do |size|
    payload = 'x' * size
    addr = addr_fn.call("#{transport}_#{size}")

    push = NNG::Socket::Push0.new
    pull = NNG::Socket::Pull0.new
    pull.listen(addr)
    push.dial(addr)

    # Warm up
    100.times do
      push.send(payload)
      pull.receive
    end

    Benchmark.ips do |x|
      x.config(warmup: 1, time: 3)

      x.report("#{size}B") do
        push.send(payload)
        pull.receive
      end
    end
  end

  puts
end
