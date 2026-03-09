$LOAD_PATH.unshift(File.expand_path('../../lib', __dir__))

require 'minitest/autorun'
require 'minitest/spec'
require 'async'
require 'nng'

# ZGuide Chapter 4 — Heartbeat Pattern
# Pub/Sub liveness detection: a publisher sends periodic heartbeats,
# a monitor detects when the peer goes silent (dead) and when it
# resumes (recovered), using recv_timeout as the liveness threshold.

describe 'Heartbeat' do
  it 'detects peer going down and recovering' do
    events = []

    Async do |task|
      pub = NNG::Socket::Pub0.new
      pub.listen('inproc://zg_heartbeat')

      sub = NNG::Socket::Sub0.new(prefix: 'HB')
      sub.recv_timeout = 0.3
      sub.dial('inproc://zg_heartbeat')

      sleep 0.01

      # Publisher: sends heartbeats, pauses to simulate failure, resumes
      publisher = task.async do
        seq = 0
        5.times do
          pub.send("HB:#{seq}")
          seq += 1
          sleep 0.1
        end

        puts "  publisher: simulating crash..."
        sleep 0.6

        puts "  publisher: recovering..."
        5.times do
          pub.send("HB:#{seq}")
          seq += 1
          sleep 0.1
        end
      end

      # Monitor: tracks peer liveness via heartbeat presence/absence
      alive = false
      until events.include?(:recovered)
        begin
          msg = sub.receive
          unless alive
            state = events.empty? ? :alive : :recovered
            events << state
            alive = true
            puts "  monitor: peer #{state} (#{msg.body})"
          end
        rescue Timeout::Error
          if alive
            events << :dead
            alive = false
            puts "  monitor: peer dead (no heartbeat received)"
          end
        end
      end

      publisher.stop
    end

    puts "  lifecycle: #{events.inspect}"
    assert_equal [:alive, :dead, :recovered], events
  end
end
