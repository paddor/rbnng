# frozen_string_literal: true

require 'minitest/autorun'
require 'minitest/spec'
require 'async'
require 'nng'

describe 'Pub0 / Sub0' do
  it 'subscriber receives a published message' do
    Sync do |task|
      pub = NNG::Socket::Pub0.new
      pub.listen('inproc://pubsub_basic')

      sub = NNG::Socket::Sub0.new
      sub.dial('inproc://pubsub_basic')

      sleep 0.01

      task.async { pub.send('broadcast') }
      msg = sub.receive

      assert_equal 'broadcast', msg.body
    end
  end

  it 'delivers to multiple subscribers' do
    Sync do |task|
      pub = NNG::Socket::Pub0.new
      pub.listen('inproc://pubsub_multi_sub')

      subs = 3.times.map do
        sub = NNG::Socket::Sub0.new
        sub.dial('inproc://pubsub_multi_sub')
        sub
      end

      sleep 0.01

      task.async { pub.send('fanout') }

      subs.each do |sub|
        msg = sub.receive
        assert_equal 'fanout', msg.body
      end
    end
  end

  it 'delivers multiple messages in order' do
    Sync do |task|
      pub = NNG::Socket::Pub0.new
      pub.listen('inproc://pubsub_ordering')

      sub = NNG::Socket::Sub0.new
      sub.dial('inproc://pubsub_ordering')

      sleep 0.01

      task.async do
        5.times { |i| pub.send("msg-#{i}") }
      end

      5.times do |i|
        msg = sub.receive
        assert_equal "msg-#{i}", msg.body
      end
    end
  end

  it 'subscriber joining late misses earlier messages' do
    Sync do |task|
      pub = NNG::Socket::Pub0.new
      pub.listen('inproc://pubsub_late_join')

      # Send before any subscriber connects
      pub.send('early')
      sleep 0.01

      sub = NNG::Socket::Sub0.new
      sub.dial('inproc://pubsub_late_join')
      sleep 0.01

      task.async { pub.send('late') }
      msg = sub.receive

      assert_equal 'late', msg.body
    end
  end

  it 'prefix filters messages by topic' do
    Sync do |task|
      pub = NNG::Socket::Pub0.new
      pub.listen('inproc://pubsub_prefix')

      sub_a = NNG::Socket::Sub0.new(prefix: 'weather.')
      sub_a.dial('inproc://pubsub_prefix')

      sub_b = NNG::Socket::Sub0.new(prefix: 'sports.')
      sub_b.dial('inproc://pubsub_prefix')

      sleep 0.01

      task.async do
        pub.send('weather.rain')
        pub.send('sports.goal')
        pub.send('weather.sun')
      end

      assert_equal 'weather.rain', sub_a.receive.body
      assert_equal 'weather.sun',  sub_a.receive.body

      assert_equal 'sports.goal',  sub_b.receive.body
    end
  end

  it 'no prefix subscribes to all messages' do
    Sync do |task|
      pub = NNG::Socket::Pub0.new
      pub.listen('inproc://pubsub_no_prefix')

      sub = NNG::Socket::Sub0.new
      sub.dial('inproc://pubsub_no_prefix')

      sleep 0.01

      task.async do
        pub.send('alpha')
        pub.send('beta')
      end

      assert_equal 'alpha', sub.receive.body
      assert_equal 'beta',  sub.receive.body
    end
  end

  it 'subscribe adds a topic at runtime' do
    Sync do |task|
      pub = NNG::Socket::Pub0.new
      pub.listen('inproc://pubsub_subscribe')

      sub = NNG::Socket::Sub0.new(prefix: 'weather.')
      sub.recv_timeout = 0.2
      sub.dial('inproc://pubsub_subscribe')

      sleep 0.01

      sub.subscribe('sports.')

      task.async do
        pub.send('weather.rain')
        pub.send('sports.goal')
      end

      messages = [sub.receive.body, sub.receive.body].sort
      assert_equal %w[sports.goal weather.rain], messages
    end
  end

  it 'unsubscribe removes a topic at runtime' do
    Sync do |task|
      pub = NNG::Socket::Pub0.new
      pub.listen('inproc://pubsub_unsubscribe')

      sub = NNG::Socket::Sub0.new(prefix: 'weather.')
      sub.recv_timeout = 0.2
      sub.dial('inproc://pubsub_unsubscribe')

      sleep 0.01

      sub.unsubscribe('weather.')
      sub.subscribe('sports.')

      task.async do
        pub.send('weather.rain')
        pub.send('sports.goal')
      end

      assert_equal 'sports.goal', sub.receive.body
      assert_raises(Timeout::Error) { sub.receive }
    end
  end

  it 'multiple publishers to one subscriber' do
    Sync do |task|
      sub = NNG::Socket::Sub0.new
      sub.listen('inproc://pubsub_multi_pub')

      pub1 = NNG::Socket::Pub0.new
      pub1.dial('inproc://pubsub_multi_pub')

      pub2 = NNG::Socket::Pub0.new
      pub2.dial('inproc://pubsub_multi_pub')

      sleep 0.01

      task.async { pub1.send('from-pub1') }
      task.async { pub2.send('from-pub2') }

      messages = [sub.receive.body, sub.receive.body].sort

      assert_equal ['from-pub1', 'from-pub2'], messages
    end
  end
end
