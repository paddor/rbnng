# frozen_string_literal: true

require_relative '../test_helper'
require 'async'

describe 'abstract:// transport' do
  it 'sends and receives via abstract namespace' do
    Sync do |task|
      rep = NNG::Socket::Rep0.new
      rep.listen('abstract://rbnng_test_abstract')

      req = NNG::Socket::Req0.new
      req.dial('abstract://rbnng_test_abstract')

      task.async do
        msg = rep.receive
        rep.send(msg.body)
      end

      req.send('hello')
      assert_equal 'hello', req.receive.body
    end
  end

  it 'is invisible to the filesystem' do
    sock = NNG::Socket::Pair0.new
    sock.listen('abstract://rbnng_test_no_file')

    refute File.exist?('rbnng_test_no_file')
  end

  it 'auto-generates a name when listening on abstract://' do
    sock = NNG::Socket::Pair0.new
    sock.listen('abstract://')

    url = sock.urls.first
    assert_match %r{\Aabstract://\w+\z}, url
  end

  it 'can dial to an auto-generated abstract address' do
    Sync do |task|
      rep = NNG::Socket::Rep0.new
      rep.listen('abstract://')
      resolved = rep.urls.first

      req = NNG::Socket::Req0.new
      req.dial(resolved)

      task.async do
        msg = rep.receive
        rep.send(msg.body)
      end

      req.send('auto')
      assert_equal 'auto', req.receive.body
    end
  end
end
