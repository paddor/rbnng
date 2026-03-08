require "nng"
require "benchmark"

N = (ARGV[0] || 50_000).to_i
TRANSPORTS = {
  "inproc" => "inproc://bench_latency",
  "tcp"    => "tcp://127.0.0.1:9100",
}

puts "NNG #{NNG.nng_version.join(".")} | Ruby #{RUBY_VERSION}"
puts "#{N} request/reply roundtrips"
puts

TRANSPORTS.each do |name, addr|
  puts "--- #{name} ---"

  req = NNG::Socket::Req0.new
  rep = NNG::Socket::Rep0.new
  rep.listen(addr)
  req.dial(addr)

  payload = "ping"

  # Warm up
  100.times do
    Thread.new { rep.send(rep.receive.body) }
    req.send(payload)
    req.receive
  end

  elapsed = Benchmark.realtime do
    N.times do
      Thread.new { rep.send(rep.receive.body) }
      req.send(payload)
      req.receive
    end
  end

  roundtrips_per_sec = (N / elapsed).round
  usec_per_roundtrip = (elapsed / N * 1_000_000).round(2)

  puts "#{roundtrips_per_sec} roundtrips/s"
  puts "#{usec_per_roundtrip} µs/roundtrip"
  puts
end
