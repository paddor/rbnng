# frozen_string_literal: true

require 'minitest/autorun'
require 'minitest/spec'
require 'async'
require 'nng'

MSG_SPEC_SEQ = [0]

describe NNG::Message do
  def roundtrip_msg(body)
    seq = MSG_SPEC_SEQ[0] += 1
    msg = nil
    Async do |task|
      addr = "inproc://msg_spec_roundtrip_#{seq}"
      rep = NNG::Socket::Rep0.new
      rep.listen(addr)

      req = NNG::Socket::Req0.new
      req.dial(addr)

      task.async do
        m = rep.receive
        rep.send(m.body)
      end

      req.send(body)
      msg = req.receive
    end
    msg
  end

  describe '#body' do
    it 'returns the message body' do
      msg = roundtrip_msg('hello')
      assert_equal 'hello', msg.body
    end

    it 'handles empty body' do
      msg = roundtrip_msg('')
      assert_equal '', msg.body
    end

    it 'handles binary data with null bytes' do
      msg = roundtrip_msg("\x00\x01\x02\xff")
      assert_equal "\x00\x01\x02\xff".b, msg.body.b
    end
  end

  describe '#dup' do
    it 'creates an independent copy' do
      msg = roundtrip_msg('original')
      copy = msg.dup

      assert_equal 'original', copy.body
      refute_same msg, copy
    end

    it 'copy is independent of original' do
      Async do |task|
        rep = NNG::Socket::Rep0.new(raw: true)
        rep.listen('inproc://msg_dup_independent')

        req = NNG::Socket::Req0.new
        req.dial('inproc://msg_dup_independent')

        task.async do
          msg = rep.receive
          copy = msg.dup
          rep.forward(msg)

          # original is consumed, copy still valid
          assert_predicate msg, :consumed?
          refute_predicate copy, :consumed?
          refute_empty copy.body
        end

        req.send('test')
        req.receive
      end
    end
  end

  describe '#consumed?' do
    it 'returns false for live messages' do
      msg = roundtrip_msg('alive')
      refute_predicate msg, :consumed?
    end

    it 'returns true after forward' do
      Async do |task|
        backend = NNG::Socket::Rep0.new
        backend.listen('inproc://msg_consumed_fwd')

        proxy_fe = NNG::Socket::Rep0.new(raw: true)
        proxy_fe.listen('inproc://msg_consumed_fwd_fe')

        proxy_be = NNG::Socket::Req0.new(raw: true)
        proxy_be.dial('inproc://msg_consumed_fwd')

        client = NNG::Socket::Req0.new
        client.dial('inproc://msg_consumed_fwd_fe')

        forwarded_msg = nil

        task.async do
          msg = backend.receive
          backend.send(msg.body)
        end

        task.async do
          msg = proxy_fe.receive
          forwarded_msg = msg
          proxy_be.forward(msg)
          reply = proxy_be.receive
          proxy_fe.forward(reply)
        end

        client.send('check')
        client.receive

        assert_predicate forwarded_msg, :consumed?
      end
    end
  end

  describe 'header manipulation' do
    it '#header_append adds data to the end of the header' do
      Async do |task|
        rep = NNG::Socket::Rep0.new(raw: true)
        rep.listen('inproc://msg_header_append')

        req = NNG::Socket::Req0.new
        req.dial('inproc://msg_header_append')

        task.async { req.send('test') }

        msg = rep.receive
        original_header = msg.header.dup
        msg.header_append('extra')
        assert_equal original_header + 'extra', msg.header
      end
    end

    it '#header_prepend inserts data at the start of the header' do
      Async do |task|
        rep = NNG::Socket::Rep0.new(raw: true)
        rep.listen('inproc://msg_header_prepend')

        req = NNG::Socket::Req0.new
        req.dial('inproc://msg_header_prepend')

        task.async { req.send('test') }

        msg = rep.receive
        original_header = msg.header.dup
        msg.header_prepend('front')
        assert_equal 'front' + original_header, msg.header
      end
    end

    it '#header_clear removes all header data' do
      Async do |task|
        rep = NNG::Socket::Rep0.new(raw: true)
        rep.listen('inproc://msg_header_clear')

        req = NNG::Socket::Req0.new
        req.dial('inproc://msg_header_clear')

        task.async { req.send('test') }

        msg = rep.receive
        refute_empty msg.header
        msg.header_clear
        assert_empty msg.header
      end
    end

    it '#header_trim removes bytes from the start of the header' do
      Async do |task|
        rep = NNG::Socket::Rep0.new(raw: true)
        rep.listen('inproc://msg_header_trim')

        req = NNG::Socket::Req0.new
        req.dial('inproc://msg_header_trim')

        task.async { req.send('test') }

        msg = rep.receive
        original_len = msg.header.bytesize
        msg.header_trim(4)
        assert_equal original_len - 4, msg.header.bytesize
      end
    end
  end

  describe 'body manipulation' do
    it '#body_clear removes all body data' do
      Async do |task|
        rep = NNG::Socket::Rep0.new(raw: true)
        rep.listen('inproc://msg_body_clear')

        req = NNG::Socket::Req0.new
        req.dial('inproc://msg_body_clear')

        task.async do
          msg = rep.receive
          assert_equal 'hello', msg.body
          msg.body_clear
          assert_empty msg.body
          msg.body_append('replaced')
          assert_equal 'replaced', msg.body
          rep.forward(msg)
        end

        req.send('hello')
        reply = req.receive
        assert_equal 'replaced', reply.body
      end
    end

    it '#body_append adds data to the body' do
      Async do |task|
        rep = NNG::Socket::Rep0.new(raw: true)
        rep.listen('inproc://msg_body_append')

        req = NNG::Socket::Req0.new
        req.dial('inproc://msg_body_append')

        task.async do
          msg = rep.receive
          msg.body_append(' world')
          assert_equal 'hello world', msg.body
          rep.forward(msg)
        end

        req.send('hello')
        reply = req.receive
        assert_equal 'hello world', reply.body
      end
    end
  end
end
