require 'nng'
require 'set'

ADDR = "ipc:///tmp/reqrep.ipc"

def start_client(i)
  sock = NNG::Socket::Req0.new
  sock.dial(ADDR)
  loop_times = (rand * 10).ceil
  puts "[client #{i}] sending #{loop_times} messages"
  loop_times.times do
    sock.send_msg("msg from client #{i}")
    msg = sock.get_msg
  end
  puts "[client #{i}] finished"
  sock.send_msg("fin-#{i}")
end

def start_server(total_clients)
  sock = NNG::Socket::Rep0.new
  sock.listen(ADDR)
  running_threads = Set.new
  total_clients.times do |i|
    running_threads.add i
  end
  total_finished = 0
  puts "[server] listening at #{ADDR}"
  loop do
    msg = sock.get_msg
    body = msg.body
    if body.start_with? 'fin'
      id = body.split('-')[1].to_i
      running_threads.delete(id)
      total_finished = total_finished + 1
      puts "[server] client #{id} sent 'fin' message (remaining: #{running_threads.to_a.join(', ')})"
      break if total_finished == total_clients
    else
      sock.send_msg body
    end
  end
  puts "[server] finished"
end

def start
  threads = []
  total_clients = 10

  threads << Thread.new { start_server(total_clients) }

  # Wait for server to start
  sleep 0.1

  total_clients.times { |i|
    threads << Thread.new { start_client i }
  }
  threads.each(&:join)
end

start
