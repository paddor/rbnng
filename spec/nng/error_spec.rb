# frozen_string_literal: true

require 'minitest/autorun'
require 'minitest/spec'
require 'async'
require 'nng'

describe 'Error handling' do
  it 'raises AddressInvalid for invalid URL' do
    sock = NNG::Socket::Pair0.new

    assert_raises(NNG::Error::AddressInvalid) { sock.listen('tcp://not a valid address!') }
  end

  it 'raises ConnectionRefused when dialing with no listener' do
    sock = NNG::Socket::Pair0.new

    assert_raises(NNG::Error::ConnectionRefused) { sock.dial('tcp://127.0.0.1:59999') }
  end

  it 'raises AddressInUse when listening on the same address twice' do
    sock1 = NNG::Socket::Pair0.new
    sock1.listen('inproc://error_addr_in_use')

    sock2 = NNG::Socket::Pair0.new

    assert_raises(NNG::Error::AddressInUse) { sock2.listen('inproc://error_addr_in_use') }
  end

  it 'all error classes inherit from NNG::Error::Error' do
    assert_operator NNG::Error::AddressInvalid, :<, NNG::Error::Error
    assert_operator NNG::Error::ConnectionRefused, :<, NNG::Error::Error
    assert_operator NNG::Error::AddressInUse, :<, NNG::Error::Error
    assert_operator NNG::Error::TimedOut, :<, NNG::Error::Error
    assert_operator NNG::Error::ObjectClosed, :<, NNG::Error::Error
  end

  it 'all error classes inherit from RuntimeError' do
    assert_operator NNG::Error::Error, :<, RuntimeError
  end

  it 'raises RuntimeError when forwarding a consumed message' do
    sock = NNG::Socket::Pair0.new
    sock.listen('inproc://error_double_fwd')

    Async do |task|
      sender = NNG::Socket::Pair0.new
      sender.dial('inproc://error_double_fwd')

      task.async { sender.send('test') }
      _msg = sock.receive

      # First forward would work on a raw socket, but let's just test consumed? + forward
      # Simulate consumption by forwarding via a raw socket pair
    end

    # Simpler test: create a message, forward it, try again
    Async do |task|
      backend = NNG::Socket::Rep0.new
      backend.listen('inproc://error_consumed_be')

      proxy = NNG::Socket::Rep0.new(raw: true)
      proxy.listen('inproc://error_consumed_fe')

      out = NNG::Socket::Req0.new(raw: true)
      out.dial('inproc://error_consumed_be')

      client = NNG::Socket::Req0.new
      client.dial('inproc://error_consumed_fe')

      task.async do
        msg = backend.receive
        backend.send(msg.body)
      end

      task.async do
        msg = proxy.receive
        out.forward(msg)
        assert_raises(RuntimeError) { out.forward(msg) }
        reply = out.receive
        proxy.forward(reply)
      end

      client.send('test')
      client.receive
    end
  end
end
