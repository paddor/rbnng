$LOAD_PATH.unshift(File.expand_path('../../lib', __dir__))

require 'minitest/autorun'
require 'minitest/spec'
require 'async'
require 'nng'

# ZGuide Chapter 4 — Lazy Pirate Pattern
# Client-side reliability via timeout + retry + socket recreation.
# The server simulates a crash (long delay) on one request.
# The client detects the timeout, closes the socket, creates a new one,
# and retries — demonstrating the core Lazy Pirate technique.

describe 'Lazy Pirate' do
  it 'retries and recovers from an unresponsive server' do
    port = 15_555
    addr = "tcp://127.0.0.1:#{port}"
    replies = []
    retries = 0

    Async do |task|
      # Server: Rep0 — deliberately slow on the 4th request received
      server_task = task.async do
        rep = NNG::Socket::Rep0.new
        rep.listen(addr)
        requests_handled = 0

        loop do
          msg = rep.receive
          requests_handled += 1

          # Simulate crash on the 4th request (seq 3, first attempt)
          if requests_handled == 4
            puts "  server: simulating crash on request '#{msg.body}'"
            sleep 1.5 # longer than client timeout
          end

          begin
            rep.send("reply-#{msg.body}")
            puts "  server: replied to request #{msg.body}"
          rescue NNG::Error
            puts "  server: client gone for request #{msg.body}, skipping reply"
          end
        end
      end

      sleep 0.01

      # Client: Req0 with timeout, retry, socket recreation
      5.times do |seq|
        attempts = 0

        loop do
          req = NNG::Socket::Req0.new
          req.recv_timeout = 0.5
          req.dial(addr)
          req.send(seq.to_s)

          begin
            reply = req.receive
            replies << reply.body
            puts "  client: got #{reply.body}"
            break
          rescue Timeout::Error
            retries += 1
            attempts += 1
            puts "  client: timeout on request #{seq}, retry #{attempts}"
            break if attempts >= 3 # give up after 3 retries
          ensure
            req.close
          end
        end
      end

      server_task.stop
    end

    puts "  summary: #{replies.size} replies, #{retries} retries"
    assert retries > 0, 'expected at least one retry'
    assert replies.size >= 3, 'expected most requests to succeed'
  end
end
