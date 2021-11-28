require 'nng'
require 'set'

ADDR = "ipc:///tmp/survey.ipc"

def start_client(i)
  sock = NNG::Socket::Respondent0.new
  sock.dial(ADDR)
  puts "[client #{i}] dialed to #{ADDR}"

  loop do
    msg = sock.get_msg
    break if msg.body == "fin"
    puts "[client #{i}] got survey: \"#{msg.body}\""
    sock.send_msg "response from client-#{i}"
  end

  puts "[client #{i}] finished"
end

def start_server(total_clients)
  sock = NNG::Socket::Surveyor0.new
  sock.listen(ADDR)
  puts "[server] listening at #{ADDR}"

  loop_times = (rand * 10).ceil
  puts "[server] running #{loop_times} surveys"

  loop_times.times do |i|
    puts "[server] Sending survey: \"survey-#{i}\""
    sock.send_msg "survey-#{i}"

    # sleep 1
    loop do
      msg = sock.get_msg
      puts "[server] Got survey response: \"#{msg.body}\""
    rescue NNG::Error::TimedOut => e
      puts "[server] timed out..."
      break
    end
  end

  puts "[server] finished"
  sock.send_msg "fin"
end

def start
  threads = []
  total_clients = 2

  threads << Thread.new { start_server(total_clients) }

  # Wait for server to start
  sleep 0.1

  total_clients.times { |i|
    # threads << Thread.new { start_client i }
    th = Thread.new { start_client i }
    th.abort_on_exception = true
    threads << th
  }
  threads.each(&:join)
end

start
