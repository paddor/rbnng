require 'nng'

ADDR  = "ipc:///tmp/pair.ipc"
NODE0 = "NODE0"
NODE1 = "NODE1"

def start_node(node_id, loop_times)
  sock = NNG::Socket::Pair0.new
  if node_id == NODE0
    sock.listen(ADDR)
  else
    sock.dial(ADDR)
  end
  puts "[#{node_id}] sending #{loop_times} messages"
  loop_times.times do |i|
    sock.send_msg "message-#{i} from #{node_id}"
    sleep 1
    msg = sock.get_msg
    puts "[#{node_id}] got message: \"#{msg.body}\""
  end
  puts "[#{node_id}] finished"
end

def start
  threads = []
  loop_times = 5
  threads << Thread.new { start_node(NODE0, loop_times) }
  threads << Thread.new { start_node(NODE1, loop_times) }
  threads.each(&:join)
end

start
