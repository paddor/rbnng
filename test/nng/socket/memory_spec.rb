# frozen_string_literal: true

require 'minitest/autorun'
require 'minitest/spec'
require 'async'
require 'objspace'
require 'nng'

describe 'Message memory management' do
  it 'collects messages after receive' do
    Sync do |task|
      rep = NNG::Socket::Rep0.new
      rep.listen('inproc://mem_collect')

      req = NNG::Socket::Req0.new
      req.dial('inproc://mem_collect')

      task.async do
        20.times do
          msg = rep.receive
          rep.send(msg.body)
        end
      end

      20.times do |i|
        req.send("msg-#{i}")
        req.receive
      end
    end

    GC.start(full_mark: true, immediate_sweep: true)
    GC.start(full_mark: true, immediate_sweep: true)

    live = ObjectSpace.each_object(NNG::Message).count
    assert_operator live, :<=, 2, "expected most messages to be collected, got #{live} live"
  end

  it 'forward consumes the message' do
    Sync do |task|
      backend = NNG::Socket::Rep0.new
      backend.listen('inproc://mem_forward_consume')

      proxy_fe = NNG::Socket::Rep0.new(raw: true)
      proxy_fe.listen('inproc://mem_forward_consume_fe')

      proxy_be = NNG::Socket::Req0.new(raw: true)
      proxy_be.dial('inproc://mem_forward_consume')

      client = NNG::Socket::Req0.new
      client.dial('inproc://mem_forward_consume_fe')

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
      backend.listen('inproc://mem_forward_leak')

      proxy_fe = NNG::Socket::Rep0.new(raw: true)
      proxy_fe.listen('inproc://mem_forward_leak_fe')

      proxy_be = NNG::Socket::Req0.new(raw: true)
      proxy_be.dial('inproc://mem_forward_leak')

      client = NNG::Socket::Req0.new
      client.dial('inproc://mem_forward_leak_fe')

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
      rep.listen('inproc://mem_unread')

      req = NNG::Socket::Req0.new
      req.dial('inproc://mem_unread')

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

  it 'does not grow memory over many send/receive cycles' do
    Sync do |task|
      rep = NNG::Socket::Rep0.new
      rep.listen('inproc://mem_growth')

      req = NNG::Socket::Req0.new
      req.dial('inproc://mem_growth')

      task.async do
        200.times do
          msg = rep.receive
          rep.send(msg.body)
        end
      end

      # Warm up
      10.times do |i|
        req.send("warmup-#{i}")
        req.receive
      end

      GC.start(full_mark: true, immediate_sweep: true)
      before = GC.stat[:heap_live_slots]

      190.times do |i|
        req.send("x" * 1024)
        req.receive
      end

      GC.start(full_mark: true, immediate_sweep: true)
      after = GC.stat[:heap_live_slots]

      # Allow some variance but not proportional to message count
      growth = after - before
      assert_operator growth, :<, 100, "heap grew by #{growth} slots over 190 cycles"
    end
  end
end
