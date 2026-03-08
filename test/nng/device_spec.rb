# frozen_string_literal: true

require 'minitest/autorun'
require 'minitest/spec'
require 'async'
require 'nng'

describe NNG::Device do
  def start_device(sock1, sock2)
    @device_sockets = [sock1, sock2]
    @device_thread = Thread.new do
      NNG::Device.start(sock1, sock2)
    rescue NNG::Error::ObjectClosed
      # expected when sockets close
    end
  end

  after do
    @device_sockets&.each { |s| s.close rescue nil }
    @device_thread&.join(1)
  end

  it 'proxies req/rep between two raw sockets' do
    Async do |task|
      backend = NNG::Socket::Rep0.new
      backend.listen('inproc://device_reqrep_be')

      frontend = NNG::Socket::Rep0.new(raw: true)
      frontend.listen('inproc://device_reqrep_fe')

      backend_raw = NNG::Socket::Req0.new(raw: true)
      backend_raw.dial('inproc://device_reqrep_be')

      client = NNG::Socket::Req0.new
      client.dial('inproc://device_reqrep_fe')

      start_device(frontend, backend_raw)

      task.async do
        msg = backend.receive
        backend.send("device:#{msg.body}")
      end

      client.send('hello')
      reply = client.receive

      assert_equal 'device:hello', reply.body
    end
  end

  it 'proxies push/pull pipeline' do
    Async do |task|
      frontend = NNG::Socket::Pull0.new(raw: true)
      frontend.listen('inproc://device_pipeline_fe')

      backend_push = NNG::Socket::Push0.new(raw: true)
      backend_push.listen('inproc://device_pipeline_be')

      worker = NNG::Socket::Pull0.new
      worker.dial('inproc://device_pipeline_be')

      producer = NNG::Socket::Push0.new
      producer.dial('inproc://device_pipeline_fe')

      start_device(frontend, backend_push)
      sleep 0.01

      task.async { producer.send('work item') }
      msg = worker.receive

      assert_equal 'work item', msg.body
    end
  end

  it 'proxies multiple messages' do
    Async do |task|
      backend = NNG::Socket::Rep0.new
      backend.listen('inproc://device_multi_be')

      frontend = NNG::Socket::Rep0.new(raw: true)
      frontend.listen('inproc://device_multi_fe')

      backend_raw = NNG::Socket::Req0.new(raw: true)
      backend_raw.dial('inproc://device_multi_be')

      client = NNG::Socket::Req0.new
      client.dial('inproc://device_multi_fe')

      start_device(frontend, backend_raw)

      task.async do
        5.times do
          msg = backend.receive
          backend.send("re:#{msg.body}")
        end
      end

      5.times do |i|
        client.send("msg-#{i}")
        reply = client.receive
        assert_equal "re:msg-#{i}", reply.body
      end
    end
  end
end
