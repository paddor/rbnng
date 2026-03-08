require "nng"
require "benchmark"

N = (ARGV[0] || 100_000).to_i
MSG_SIZES = [64, 256, 1024, 4096]
TRANSPORTS = {
  "inproc" => ->(size) { "inproc://bench_throughput_#{size}" },
  "tcp"    => ->(size) { "tcp://127.0.0.1:#{9000 + size}" },
}

puts "NNG #{NNG.nng_version.join(".")} | Ruby #{RUBY_VERSION}"
puts "#{N} roundtrips per message size"
puts

TRANSPORTS.each do |name, addr_fn|
  puts "--- #{name} ---"

  MSG_SIZES.each do |size|
    payload = "x" * size
    addr = addr_fn.call(size)

    push = NNG::Socket::Push0.new
    pull = NNG::Socket::Pull0.new
    pull.listen(addr)
    push.dial(addr)

    # Warm up
    100.times do
      push.send(payload)
      pull.receive
    end

    elapsed = Benchmark.realtime do
      N.times do
        push.send(payload)
        pull.receive
      end
    end

    msgs_per_sec = (N / elapsed).round
    mb_per_sec = (N * size / elapsed / 1024.0 / 1024.0).round(2)
    usec_per_msg = (elapsed / N * 1_000_000).round(2)

    puts "#{size.to_s.rjust(5)}B  #{msgs_per_sec.to_s.rjust(10)} msg/s  #{mb_per_sec.to_s.rjust(10)} MB/s  #{usec_per_msg.to_s.rjust(8)} µs/msg"
  end

  puts
end
