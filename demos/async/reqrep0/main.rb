#! /usr/bin/env ruby

require 'bundler/inline'

gemfile do
  source 'https://rubygems.org'
  gem 'async'
  gem 'nng', path: File.expand_path('../../..', __dir__)
end

ADDR = "ipc:///tmp/rbnng_req0_test"

Async do |task|
  task.async do
    4.times do
      sleep 1
      puts "foo"
    end
  end

  task.async do
    s = NNG::Socket::Rep0.new
    s.recv_timeout = 2
    p recv_timeout: s.recv_timeout
    s.listen ADDR
    begin
      msg = s.get_msg
    rescue IO::TimeoutError
      puts "REP: got timeout"
      retry
    end
    puts "REP: #{msg.inspect}"
    p msg.body if msg
  end

  task.async do
    s = NNG::Socket::Req0.new
    s.send_timeout = 2
    p send_timeout: s.send_timeout

    sleep 3
    s.dial ADDR
    s.send_msg "MSG1"
  end
end
