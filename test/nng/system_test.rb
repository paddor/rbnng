# frozen_string_literal: true

require_relative '../test_helper'
require 'async'
require 'objspace'

describe 'System: memory' do
  it 'does not leak sockets created in a loop' do
    100.times { NNG::Socket::Pair0.new }

    GC.start(full_mark: true, immediate_sweep: true)
    GC.start(full_mark: true, immediate_sweep: true)

    live = ObjectSpace.each_object(NNG::Socket::Pair0).count
    assert_operator live, :<, 10, "expected most sockets to be collected, got #{live} live"
  end

  it 'does not leak sockets after explicit close' do
    100.times do
      s = NNG::Socket::Pair0.new
      s.close
    end

    GC.start(full_mark: true, immediate_sweep: true)
    GC.start(full_mark: true, immediate_sweep: true)

    live = ObjectSpace.each_object(NNG::Socket::Pair0).count
    assert_operator live, :<, 10, "expected most sockets to be collected, got #{live} live"
  end

  it 'does not leak messages under rapid send/receive' do
    n = 500

    Sync do |task|
      rep = NNG::Socket::Rep0.new
      rep.listen('inproc://sys_msg_leak')

      req = NNG::Socket::Req0.new
      req.dial('inproc://sys_msg_leak')

      task.async do
        n.times do
          msg = rep.receive
          rep.send(msg.body)
        end
      end

      n.times do |i|
        req.send("m-#{i}")
        req.receive
      end
    end

    GC.start(full_mark: true, immediate_sweep: true)
    GC.start(full_mark: true, immediate_sweep: true)

    live = ObjectSpace.each_object(NNG::Message).count
    assert_operator live, :<=, 5, "expected most messages to be collected, got #{live} live"
  end

  it 'does not grow heap over many large message cycles' do
    n = 500
    payload = 'X' * 4096

    Sync do |task|
      rep = NNG::Socket::Rep0.new
      rep.listen('inproc://sys_heap_growth')

      req = NNG::Socket::Req0.new
      req.dial('inproc://sys_heap_growth')

      task.async do
        n.times do
          msg = rep.receive
          rep.send(msg.body)
        end
      end

      # warm up
      20.times do
        req.send(payload)
        req.receive
      end

      GC.start(full_mark: true, immediate_sweep: true)
      before = GC.stat[:heap_live_slots]

      (n - 20).times do
        req.send(payload)
        req.receive
      end

      GC.start(full_mark: true, immediate_sweep: true)
      after = GC.stat[:heap_live_slots]

      growth = after - before
      assert_operator growth, :<, 200, "heap grew by #{growth} slots over #{n - 20} cycles with 4KB payloads"
    end
  end

  it 'forward consumes the message' do
    Sync do |task|
      backend = NNG::Socket::Rep0.new
      backend.listen('inproc://sys_forward_consume')

      proxy_fe = NNG::Socket::Rep0.new(raw: true)
      proxy_fe.listen('inproc://sys_forward_consume_fe')

      proxy_be = NNG::Socket::Req0.new(raw: true)
      proxy_be.dial('inproc://sys_forward_consume')

      client = NNG::Socket::Req0.new
      client.dial('inproc://sys_forward_consume_fe')

      consumed_msg = nil

      task.async do
        msg = backend.receive
        backend.send(msg.body)
      end

      task.async do
        msg = proxy_fe.receive
        consumed_msg = msg
        proxy_be.forward(msg)
        reply = proxy_be.receive
        proxy_fe.forward(reply)
      end

      client.send('hello')
      client.receive

      # The forwarded message should be consumed (pointer nulled)
      assert_raises(RuntimeError) { proxy_be.forward(consumed_msg) }
    end
  end

  it 'does not leak messages during repeated forward cycles' do
    Sync do |task|
      backend = NNG::Socket::Rep0.new
      backend.listen('inproc://sys_forward_leak')

      proxy_fe = NNG::Socket::Rep0.new(raw: true)
      proxy_fe.listen('inproc://sys_forward_leak_fe')

      proxy_be = NNG::Socket::Req0.new(raw: true)
      proxy_be.dial('inproc://sys_forward_leak')

      client = NNG::Socket::Req0.new
      client.dial('inproc://sys_forward_leak_fe')

      n = 50

      task.async do
        n.times do
          msg = backend.receive
          backend.send(msg.body)
        end
      end

      task.async do
        n.times do
          msg = proxy_fe.receive
          proxy_be.forward(msg)
          reply = proxy_be.receive
          proxy_fe.forward(reply)
        end
      end

      n.times do |i|
        client.send("msg-#{i}")
        reply = client.receive
        assert_equal "msg-#{i}", reply.body
      end
    end

    GC.start(full_mark: true, immediate_sweep: true)
    GC.start(full_mark: true, immediate_sweep: true)

    live = ObjectSpace.each_object(NNG::Message).count
    assert_operator live, :<=, 2, "expected most messages to be collected, got #{live} live"
  end

  it 'does not leak when messages go out of scope without being read' do
    Sync do |task|
      rep = NNG::Socket::Rep0.new
      rep.listen('inproc://sys_unread')

      req = NNG::Socket::Req0.new
      req.dial('inproc://sys_unread')

      task.async do
        20.times do
          msg = rep.receive
          rep.send(msg.body)
        end
      end

      20.times do |i|
        req.send("msg-#{i}")
        req.receive # discard without reading body
      end
    end

    GC.start(full_mark: true, immediate_sweep: true)
    GC.start(full_mark: true, immediate_sweep: true)

    live = ObjectSpace.each_object(NNG::Message).count
    assert_operator live, :<=, 2, "expected most messages to be collected, got #{live} live"
  end

  it 'does not leak pipe notify resources' do
    20.times do
      rep = NNG::Socket::Rep0.new
      rep.listen("inproc://sys_pipe_notify_leak_#{_1}")
      rep.pipe_notify_start
      rep.close
    end

    GC.start(full_mark: true, immediate_sweep: true)
    GC.start(full_mark: true, immediate_sweep: true)

    live = ObjectSpace.each_object(NNG::Socket::Rep0).count
    assert_operator live, :<, 5, "expected pipe-notify sockets to be collected, got #{live} live"
  end
end

describe 'System: stress' do
  it 'handles many concurrent pub/sub messages' do
    n = 1000

    Sync do |task|
      pub = NNG::Socket::Pub0.new
      pub.listen('inproc://sys_pubsub_stress')

      sub = NNG::Socket::Sub0.new
      sub.dial('inproc://sys_pubsub_stress')
      sleep 0.05 # let subscription propagate

      received = 0

      reader = task.async do
        loop do
          sub.receive(timeout: 0.5)
          received += 1
        rescue Timeout::Error
          break
        end
      end

      n.times { |i| pub.send("evt-#{i}") }

      reader.wait
      assert_operator received, :>, n / 2, "expected at least half of #{n} messages, got #{received}"
    end
  end

  it 'handles many short-lived req/rep connections' do
    port = 17_000 + rand(1000)
    url = "tcp://127.0.0.1:#{port}"
    n = 50

    rep = NNG::Socket::Rep0.new
    rep.listen(url)

    Thread.new do
      n.times do
        msg = rep.receive
        rep.send(msg.body)
      end
    end

    n.times do |i|
      req = NNG::Socket::Req0.new
      req.dial(url)
      req.send("req-#{i}")
      reply = req.receive
      assert_equal "req-#{i}", reply.body
      req.close
    end

    rep.close
  end

  it 'handles rapid open/close cycles' do
    200.times do
      s = NNG::Socket::Push0.new
      s.listen("inproc://sys_open_close_#{_1}")
      s.close
    end
    # no crash = pass
  end

  it 'survives fan-out with many subscribers' do
    n_subs = 20
    n_msgs = 100

    Sync do |task|
      pub = NNG::Socket::Pub0.new
      pub.listen('inproc://sys_fanout')

      subs = n_subs.times.map do |i|
        s = NNG::Socket::Sub0.new
        s.dial('inproc://sys_fanout')
        s
      end

      sleep 0.05

      counts = Array.new(n_subs, 0)

      readers = subs.each_with_index.map do |sub, i|
        task.async do
          loop do
            sub.receive(timeout: 0.5)
            counts[i] += 1
          rescue Timeout::Error
            break
          end
        end
      end

      n_msgs.times { |i| pub.send("fan-#{i}") }

      readers.each(&:wait)

      counts.each_with_index do |c, i|
        assert_operator c, :>, 0, "subscriber #{i} received nothing"
      end
    end
  end

  it 'handles pipeline with multiple workers' do
    n_msgs = 200
    n_workers = 4
    results = Queue.new

    Sync do |task|
      push = NNG::Socket::Push0.new
      push.listen('inproc://sys_pipeline_workers')

      pulls = n_workers.times.map do
        s = NNG::Socket::Pull0.new
        s.dial('inproc://sys_pipeline_workers')
        s
      end

      workers = pulls.map do |pull|
        task.async do
          loop do
            msg = pull.receive(timeout: 0.5)
            results << msg.body
          rescue Timeout::Error
            break
          end
        end
      end

      n_msgs.times { |i| push.send("job-#{i}") }

      workers.each(&:wait)
    end

    total = results.size
    assert_equal n_msgs, total, "expected #{n_msgs} results, got #{total}"
  end

  it 'handles concurrent threads doing req/rep' do
    n_threads = 8
    n_per_thread = 50

    rep = NNG::Socket::Rep0.new
    rep.listen('inproc://sys_threaded_reqrep')

    server = Thread.new do
      (n_threads * n_per_thread).times do
        msg = rep.receive
        rep.send(msg.body.upcase)
      end
    end

    threads = n_threads.times.map do |t|
      Thread.new do
        req = NNG::Socket::Req0.new
        req.dial('inproc://sys_threaded_reqrep')

        n_per_thread.times do |i|
          payload = "t#{t}-#{i}"
          req.send(payload)
          reply = req.receive
          assert_equal payload.upcase, reply.body
        end

        req.close
      end
    end

    threads.each(&:join)
    server.join
    rep.close
  end
end
