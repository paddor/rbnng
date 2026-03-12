# frozen_string_literal: true

require_relative '../test_helper'
require 'async'

describe 'Statistics' do
  it 'NNG.stats returns a Hash with socket and listener scopes' do
    sock = NNG::Socket::Pair0.new
    sock.listen('inproc://stats_basic')

    stats = NNG.stats
    assert_instance_of Hash, stats
    assert_includes stats.keys, :socket
  end

  it 'NNG.stats_for returns per-socket statistics' do
    Sync do |task|
      s1 = NNG::Socket::Pair0.new
      s1.listen('inproc://stats_for_test')

      s2 = NNG::Socket::Pair0.new
      s2.dial('inproc://stats_for_test')
      sleep 0.01

      task.async { s1.send('hello') }
      s2.receive

      stats = NNG.stats_for(s1)
      assert_instance_of Hash, stats
      assert_equal 'pair', stats[:protocol][:value]
      assert_includes stats.keys, :tx_msgs
    end
  end
end
