$LOAD_PATH.unshift(File.expand_path('../../lib', __dir__))

require 'minitest/autorun'
require 'minitest/spec'
require 'async'
require 'nng'

# ZGuide Chapters 1 & 2 — Advanced Pub/Sub Patterns
# Demonstrates: Device proxy, topic filtering, and fan-out
# to multiple subscribers.

describe 'Advanced Pub/Sub' do
  it 'forwards messages through a proxy' do
    # Manual forwarder proxy: Sub0 receives from publishers,
    # Pub0 re-publishes to subscribers. This is the NNG equivalent
    # of ZMQ's XSUB/XPUB proxy pattern.
    received = []

    Sync do |task|
      proxy_sub = NNG::Socket::Sub0.new
      proxy_sub.listen('inproc://zg_proxy_fe')

      proxy_pub = NNG::Socket::Pub0.new
      proxy_pub.listen('inproc://zg_proxy_be')

      # Forwarder fiber: receives from frontend, sends to backend
      forwarder = task.async do
        loop do
          msg = proxy_sub.receive
          proxy_pub.send(msg.body)
        end
      end

      pub = NNG::Socket::Pub0.new
      pub.dial('inproc://zg_proxy_fe')

      sub = NNG::Socket::Sub0.new
      sub.dial('inproc://zg_proxy_be')

      sleep 0.05 # let connections establish through proxy

      task.async do
        3.times { |i| pub.send("proxied-#{i}") }
      end

      3.times do
        msg = sub.receive
        received << msg.body
        puts "  proxy: received '#{msg.body}'"
      end

      forwarder.stop
    end

    assert_equal %w[proxied-0 proxied-1 proxied-2], received
  end

  it 'filters by topic prefix' do
    weather_msgs = []
    sports_msgs = []

    Sync do |task|
      pub = NNG::Socket::Pub0.new
      pub.listen('inproc://zg_pubsub_filter')

      weather_sub = NNG::Socket::Sub0.new(prefix: 'weather.')
      weather_sub.dial('inproc://zg_pubsub_filter')

      sports_sub = NNG::Socket::Sub0.new(prefix: 'sports.')
      sports_sub.dial('inproc://zg_pubsub_filter')

      sleep 0.01

      task.async do
        pub.send('weather.rain')
        pub.send('sports.goal')
        pub.send('weather.sun')
        pub.send('sports.try')
      end

      # weather subscriber gets weather messages only
      weather_msgs << weather_sub.receive.body
      weather_msgs << weather_sub.receive.body

      # sports subscriber gets sports messages only
      sports_msgs << sports_sub.receive.body
      sports_msgs << sports_sub.receive.body
    end

    puts "  weather subscriber got: #{weather_msgs.inspect}"
    puts "  sports subscriber got:  #{sports_msgs.inspect}"

    assert_equal %w[weather.rain weather.sun], weather_msgs
    assert_equal %w[sports.goal sports.try], sports_msgs
  end

  it 'fan-out to multiple subscribers' do
    received = Array.new(3) { [] }

    Sync do |task|
      pub = NNG::Socket::Pub0.new
      pub.listen('inproc://zg_pubsub_fanout')

      subs = 3.times.map do
        sub = NNG::Socket::Sub0.new
        sub.dial('inproc://zg_pubsub_fanout')
        sub
      end

      sleep 0.01

      task.async do
        pub.send('broadcast-1')
        pub.send('broadcast-2')
      end

      subs.each_with_index do |sub, i|
        2.times do
          msg = sub.receive
          received[i] << msg.body
          puts "  subscriber-#{i}: got '#{msg.body}'"
        end
      end
    end

    received.each_with_index do |msgs, i|
      assert_equal %w[broadcast-1 broadcast-2], msgs,
        "subscriber-#{i} should receive both messages"
    end
  end
end
