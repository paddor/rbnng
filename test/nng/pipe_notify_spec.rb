# frozen_string_literal: true

require 'minitest/autorun'
require 'minitest/spec'
require 'async'
require 'nng'

describe 'Pipe notifications' do
  it 'fires :connect and :disconnect events' do
    port = 15_580 + rand(1000)
    rep = NNG::Socket::Rep0.new
    rep.listen("tcp://127.0.0.1:#{port}")
    rep.pipe_notify_start
    io = IO.for_fd(rep.pipe_notify_fd, autoclose: false)

    req = NNG::Socket::Req0.new
    req.dial("tcp://127.0.0.1:#{port}")
    sleep 0.1

    io.wait_readable(1)
    event, pipe = rep.recv_pipe_event

    assert_equal :connect, event
    assert_instance_of NNG::Pipe, pipe
    assert_kind_of Integer, pipe.id

    req.close
    sleep 0.2

    io.wait_readable(1)
    event2, pipe2 = rep.recv_pipe_event

    assert_equal :disconnect, event2
    assert_instance_of NNG::Pipe, pipe2
  end

  it 'each_pipe_event yields events via Async' do
    port = 16_580 + rand(1000)
    events = []

    Sync do |task|
      rep = NNG::Socket::Rep0.new
      rep.listen("tcp://127.0.0.1:#{port}")

      watcher = task.async do
        rep.each_pipe_event do |event, pipe|
          events << [event, pipe.id]
          break if event == :disconnect
        end
      end

      sleep 0.05
      req = NNG::Socket::Req0.new
      req.dial("tcp://127.0.0.1:#{port}")
      sleep 0.1
      req.close

      watcher.wait
    end

    assert_equal 2, events.size
    assert_equal :connect, events[0][0]
    assert_equal :disconnect, events[1][0]
  end
end
