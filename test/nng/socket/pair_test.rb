# frozen_string_literal: true

require_relative '../../test_helper'
require 'async'

describe NNG::Socket::Pair0 do
  it 'can send and receive a message' do
    Sync do |task|
      listener = NNG::Socket::Pair0.new
      listener.listen('inproc://pair0_spec')

      dialer = NNG::Socket::Pair0.new
      dialer.dial('inproc://pair0_spec')

      task.async { dialer.send('hello from pair0') }
      msg = listener.receive

      assert_equal 'hello from pair0', msg.body
    end
  end

  it 'opens in raw mode' do
    sock = NNG::Socket::Pair0.new(raw: true)
    refute_nil sock
  end

  it 'includes Readable' do
    assert_includes NNG::Socket::Pair0.ancestors, NNG::Socket::Readable
  end

  it 'includes Writable' do
    assert_includes NNG::Socket::Pair0.ancestors, NNG::Socket::Writable
  end

  it 'exposes wait_readable' do
    assert_respond_to NNG::Socket::Pair0.new, :wait_readable
  end

  it 'exposes wait_writable' do
    assert_respond_to NNG::Socket::Pair0.new, :wait_writable
  end

  it 'receive times out when no message arrives' do
    sock = NNG::Socket::Pair0.new
    sock.listen('inproc://pair0_recv_timeout')

    assert_raises(Timeout::Error) { sock.receive(timeout: 0.01) }
  end

  it 'wait_readable returns nil on timeout' do
    sock = NNG::Socket::Pair0.new
    sock.listen('inproc://pair0_wait_timeout')

    assert_nil sock.wait_readable(0.01)
  end

  it 'receive uses recv_timeout as default timeout' do
    sock = NNG::Socket::Pair0.new
    sock.listen('inproc://pair0_default_recv_timeout')
    sock.recv_timeout = 0.01

    assert_raises(Timeout::Error) { sock.receive }
  end

  it 'wait_readable uses recv_timeout as default timeout' do
    sock = NNG::Socket::Pair0.new
    sock.listen('inproc://pair0_default_wait_readable')
    sock.recv_timeout = 0.01

    assert_nil sock.wait_readable
  end

  it 'send uses send_timeout as default timeout' do
    sock = NNG::Socket::Pair0.new
    sock.listen('inproc://pair0_default_send_timeout')
    sock.send_timeout = 0.01

    assert_raises(Timeout::Error) { sock.send('hello') }
  end

  it 'wait_writable uses send_timeout as default timeout' do
    sock = NNG::Socket::Pair0.new
    sock.listen('inproc://pair0_default_wait_writable')
    sock.send_timeout = 0.01

    assert_nil sock.wait_writable
  end

  it 'receive works with explicit timeout when data is available' do
    Sync do |task|
      listener = NNG::Socket::Pair0.new
      listener.listen('inproc://pair0_recv_timeout_ok')

      dialer = NNG::Socket::Pair0.new
      dialer.dial('inproc://pair0_recv_timeout_ok')

      task.async { dialer.send('hello') }
      msg = listener.receive(timeout: 1)

      assert_equal 'hello', msg.body
    end
  end
end

describe NNG::Socket::Pair1 do
  it 'can send and receive a message' do
    Sync do |task|
      listener = NNG::Socket::Pair1.new
      listener.listen('inproc://pair1_spec')

      dialer = NNG::Socket::Pair1.new
      dialer.dial('inproc://pair1_spec')

      task.async { dialer.send('hello from pair1') }
      msg = listener.receive

      assert_equal 'hello from pair1', msg.body
    end
  end
end
