require 'nng'

ADDR = "ipc:///tmp/pubsub.ipc"

def start_subscriber(i)
  sock = NNG::Socket::Sub0.new
  sock.dial(ADDR)
  puts "[client #{i}] dialed to #{ADDR}"

  loop do
    msg = sock.get_msg
    break if msg.body == "fin"
    puts "[client #{i}] got message: #{msg.body}"
  end
  puts "[client #{i}] finished"
end

def start_publisher
  sock = NNG::Socket::Pub0.new
  sock.listen(ADDR)
  puts "[publisher] listening at #{ADDR}"

  # Wait for clients to connect
  sleep 0.1

  loop_times = (rand * 10).ceil
  puts "[publisher] publishing #{loop_times} messages"
  loop_times.times do |i|
    sock.send_msg "message-#{i}"
    sleep 0.1
  end

  puts "[publisher] finished"
  sock.send_msg "fin"
end

def start
  threads = []
  total_subs = 3

  threads << Thread.new { start_publisher }

  total_subs.times { |i|
    threads << Thread.new { start_subscriber i }
  }
  threads.each(&:join)
end

start
