require 'nng'
require 'set'

# TODO: currently segfaulting

def start_node(i, total_nodes)
  sock = NNG::Socket::Bus0.new
  addr = "ipc:///tmp/bus-node-#{i}.ipc"
  sock.listen(addr)
  puts "[node-#{i}] listening on #{addr}"
  
  # Wait for peers to listen
  sleep 1

  running_nodes = Set.new
  total_nodes.times do |n_i|
    next if i == n_i
    node_addr = "ipc:///tmp/bus-node-#{n_i}.ipc"
    sock.dial(node_addr)
    puts "[node-#{i}] dialed to #{node_addr}"
    running_nodes.add n_i
  end

  loop_times = (rand * 10).ceil
  puts "[node-#{i}] sending #{loop_times} messages"
  loop_times.times do |l_i|
    sock.send_msg "message-#{l_i} from node-#{i}"
  end

  puts "[node-#{i}] finished sending"
  sock.send_msg "fin-#{i}"

  loop do
    msg = sock.get_msg
    body = msg.body
    puts "[node-#{i}] got message: \"#{body}\""
    if body.start_with? 'fin'
      id = body.split('-')[1].to_i
      running_nodes.delete(id)
      puts "[node-#{i}] node #{id} sent 'fin' message (remaining: #{running_nodes.to_a.join(', ')})"
      break if running_nodes.empty?
    end
  end

  puts "[node-#{i}] finished"
end

def start
  threads = []
  total_nodes = 3
  total_nodes.times { |i|
    threads << Thread.new { start_node i, total_nodes }
  }
  threads.each(&:join)
end

start
