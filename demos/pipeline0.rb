require 'nng'

def start_puller(i)
  sock = NNG::Socket::Pull0.new
  addr = "ipc:///tmp/puller-#{i}.ipc"
  sock.listen(addr)
  puts "[puller] listening at #{addr}"

  loop do
    msg = sock.get_msg
    body = msg.body
    break if body == "fin"
    puts "[puller #{i}] got message: \"#{body}\""
  end
  puts "[puller #{i}] finished"
end

def start_pusher(total_pullers)
  sock = NNG::Socket::Push0.new
  total_pullers.times do |i|
    sock.dial("ipc:///tmp/puller-#{i}.ipc")
  end

  loop_times = (rand * 10).ceil
  puts "[pusher] sending #{loop_times} messages"
  loop_times.times do |i|
    sock.send_msg("msg-#{i}")
    sleep 0.1
  end

  # Send fin to all pullers
  total_pullers.times do
    sock.send_msg("fin")
  end

  puts "[pusher] finished"
end

def start
  threads = []
  total_pullers = 5

  total_pullers.times { |i|
    threads << Thread.new { start_puller i }
  }

  # Wait for pullers to start
  sleep 0.5

  threads << Thread.new { start_pusher(total_pullers) }

  threads.each(&:join)
end

start
