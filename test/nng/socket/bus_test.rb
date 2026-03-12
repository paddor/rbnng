# frozen_string_literal: true

require_relative '../../test_helper'
require 'async'

describe NNG::Socket::Bus0 do
  it 'broadcasts to all connected nodes' do
    Sync do |task|
      node0 = NNG::Socket::Bus0.new
      node0.listen('inproc://bus_spec_0')

      node1 = NNG::Socket::Bus0.new
      node1.listen('inproc://bus_spec_1')

      node0.dial('inproc://bus_spec_1')
      node1.dial('inproc://bus_spec_0')

      sleep 0.01

      received = nil
      task.async { received = node1.receive }

      node0.send('bus message')

      sleep 0.05
      assert_equal 'bus message', received&.body
    end
  end
end
