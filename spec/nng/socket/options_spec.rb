# frozen_string_literal: true

require 'minitest/autorun'
require 'minitest/spec'
require 'nng'

describe 'Socket options' do
  describe '#name / #name=' do
    it 'sets and gets the socket name' do
      sock = NNG::Socket::Pair0.new
      sock.name = 'my-socket'

      assert_equal 'my-socket', sock.name
    end
  end

  describe '#urls' do
    it 'returns an empty array before listen or dial' do
      sock = NNG::Socket::Pair0.new

      assert_equal [], sock.urls
    end

    it 'tracks listen URLs' do
      sock = NNG::Socket::Pair0.new
      sock.listen('inproc://opts_url_listen')

      assert_equal ['inproc://opts_url_listen'], sock.urls
    end

    it 'tracks dial URLs' do
      listener = NNG::Socket::Pair0.new
      listener.listen('inproc://opts_url_dial')

      dialer = NNG::Socket::Pair0.new
      dialer.dial('inproc://opts_url_dial')

      assert_equal ['inproc://opts_url_dial'], dialer.urls
    end

    it 'accumulates multiple URLs' do
      sock = NNG::Socket::Pair0.new
      sock.listen('inproc://opts_url_multi_a')
      sock.listen('inproc://opts_url_multi_b')

      assert_equal ['inproc://opts_url_multi_a', 'inproc://opts_url_multi_b'], sock.urls
    end

    it 'returns a frozen copy' do
      sock = NNG::Socket::Pair0.new
      sock.listen('inproc://opts_url_frozen')

      assert_predicate sock.urls, :frozen?
    end
  end

  describe '#recv_buffer / #recv_buffer=' do
    it 'sets and gets the receive buffer size' do
      sock = NNG::Socket::Pair0.new
      sock.recv_buffer = 16

      assert_equal 16, sock.recv_buffer
    end
  end

  describe '#send_buffer / #send_buffer=' do
    it 'sets and gets the send buffer size' do
      sock = NNG::Socket::Pair0.new
      sock.send_buffer = 16

      assert_equal 16, sock.send_buffer
    end
  end

  describe '#recv_max_size / #recv_max_size=' do
    it 'sets and gets the max receive size' do
      sock = NNG::Socket::Pair0.new
      sock.recv_max_size = 65536

      assert_equal 65536, sock.recv_max_size
    end
  end

  describe '#reconnect_time / #reconnect_time=' do
    it 'returns a Range of seconds' do
      sock = NNG::Socket::Pair0.new
      range = sock.reconnect_time

      assert_kind_of Range, range
      assert_kind_of Float, range.begin
      assert_kind_of Float, range.end
    end

    it 'sets min and max from a Range' do
      sock = NNG::Socket::Pair0.new
      sock.reconnect_time = 0.1..5.0

      range = sock.reconnect_time
      assert_in_delta 0.1, range.begin, 0.001
      assert_in_delta 5.0, range.end, 0.001
    end

    it 'accepts integer seconds' do
      sock = NNG::Socket::Pair0.new
      sock.reconnect_time = 1..10

      range = sock.reconnect_time
      assert_in_delta 1.0, range.begin, 0.001
      assert_in_delta 10.0, range.end, 0.001
    end
  end

  describe '#protocol_name' do
    it 'returns the protocol name' do
      assert_equal 'pair', NNG::Socket::Pair0.new.protocol_name
    end

    it 'returns the correct name for each protocol' do
      assert_equal 'req', NNG::Socket::Req0.new.protocol_name
      assert_equal 'rep', NNG::Socket::Rep0.new.protocol_name
      assert_equal 'pub', NNG::Socket::Pub0.new.protocol_name
      assert_equal 'sub', NNG::Socket::Sub0.new.protocol_name
      assert_equal 'push', NNG::Socket::Push0.new.protocol_name
      assert_equal 'pull', NNG::Socket::Pull0.new.protocol_name
    end
  end

  describe '#raw?' do
    it 'returns false for cooked sockets' do
      refute_predicate NNG::Socket::Pair0.new, :raw?
    end

    it 'returns true for raw sockets' do
      assert_predicate NNG::Socket::Pair0.new(raw: true), :raw?
    end
  end

  describe '#recv_timeout / #send_timeout' do
    it 'defaults to infinite (-1)' do
      sock = NNG::Socket::Pair0.new

      assert_equal(-1, sock.recv_timeout)
      assert_equal(-1, sock.send_timeout)
    end

    it 'sets recv timeout in milliseconds' do
      sock = NNG::Socket::Pair0.new
      sock.recv_timeout = 500

      assert_equal 500, sock.recv_timeout
    end

    it 'sets send timeout in milliseconds' do
      sock = NNG::Socket::Pair0.new
      sock.send_timeout = 500

      assert_equal 500, sock.send_timeout
    end
  end
end
