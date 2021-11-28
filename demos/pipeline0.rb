require 'nng'
require 'set'

ADDR = "ipc:///tmp/pipeline.ipc"

def start_pusher(i)
  sock = NNG::Socket::Push0.new
  sock.dial(ADDR)
  loop_times = (rand * 10).ceil
  puts "[pusher #{i}] sending #{loop_times} messages"
  loop_times.times do |l_i|
    sock.send_msg("msg-#{l_i} from pusher-#{i}")
    sleep 0.1
  end
  puts "[pusher #{i}] finished"
  sock.send_msg("fin-#{i}")
end

def start_puller(total_pushers)
  sock = NNG::Socket::Pull0.new
  sock.listen(ADDR)
  running_set = Set.new
  total_pushers.times do |i|
    running_set.add i
  end
  puts "[puller] listening at #{ADDR}"
  loop do
    msg = sock.get_msg
    body = msg.body
    if body.start_with? 'fin'
      id = body.split('-')[1].to_i
      running_set.delete(id)
      puts "[puller] client #{id} sent 'fin' message (remaining: #{running_set.to_a.join(', ')})"
      break if running_set.empty?
    else
      puts "[puller] got message: \"#{body}\""
    end
  end
  puts "[puller] finished"
end

def start
  threads = []
  total_pushers = 5

  threads << Thread.new { start_puller(total_pushers) }

  # Wait for puller to start
  sleep 0.1

  total_pushers.times { |i|
    threads << Thread.new { start_pusher i }
  }
  threads.each(&:join)
end

start
