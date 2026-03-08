require "minitest/autorun"
require "minitest/spec"
require "async"
require "nng"

describe "Req0 / Rep0" do
  it "completes a request/reply roundtrip" do
    Async do |task|
      rep = NNG::Socket::Rep0.new
      rep.listen("inproc://reqrep_basic")

      req = NNG::Socket::Req0.new
      req.dial("inproc://reqrep_basic")

      task.async do
        request = rep.receive
        assert_equal "ping", request.body
        rep.send("pong")
      end

      req.send("ping")
      reply = req.receive

      assert_equal "pong", reply.body
    end
  end

  it "handles multiple sequential requests" do
    Async do |task|
      rep = NNG::Socket::Rep0.new
      rep.listen("inproc://reqrep_sequential")

      req = NNG::Socket::Req0.new
      req.dial("inproc://reqrep_sequential")

      task.async do
        5.times do
          msg = rep.receive
          rep.send("re: #{msg.body}")
        end
      end

      5.times do |i|
        req.send("msg-#{i}")
        reply = req.receive
        assert_equal "re: msg-#{i}", reply.body
      end
    end
  end

  it "serves multiple clients" do
    Async do |task|
      rep = NNG::Socket::Rep0.new
      rep.listen("inproc://reqrep_multi_client")

      clients = 3.times.map do |i|
        req = NNG::Socket::Req0.new
        req.dial("inproc://reqrep_multi_client")
        req
      end

      task.async do
        (3 * 3).times do
          msg = rep.receive
          rep.send("ack:#{msg.body}")
        end
      end

      replies = []
      clients.each_with_index do |req, i|
        3.times do |j|
          req.send("c#{i}-#{j}")
          replies << req.receive.body
        end
      end

      assert_equal 9, replies.length
      replies.each { |r| assert_match(/\Aack:c\d-\d\z/, r) }
    end
  end

  it "proxies a request through a middle rep/req pair" do
    Async do |task|
      # Backend: the service that does the actual work
      backend = NNG::Socket::Rep0.new
      backend.listen("inproc://reqrep_backend")

      # Proxy: receives from frontend, forwards to backend, returns reply
      proxy_frontend = NNG::Socket::Rep0.new
      proxy_frontend.listen("inproc://reqrep_proxy")

      proxy_backend = NNG::Socket::Req0.new
      proxy_backend.dial("inproc://reqrep_backend")

      # Client
      client = NNG::Socket::Req0.new
      client.dial("inproc://reqrep_proxy")

      # Backend echoes with prefix
      task.async do
        msg = backend.receive
        backend.send("backend:#{msg.body}")
      end

      # Proxy forwards request and relays reply
      task.async do
        msg = proxy_frontend.receive
        proxy_backend.send(msg.body)
        reply = proxy_backend.receive
        proxy_frontend.send(reply.body)
      end

      client.send("hello")
      reply = client.receive

      assert_equal "backend:hello", reply.body
    end
  end

  it "proxies multiple requests through a middle rep/req pair" do
    Async do |task|
      backend = NNG::Socket::Rep0.new
      backend.listen("inproc://reqrep_proxy_multi")

      proxy_frontend = NNG::Socket::Rep0.new
      proxy_frontend.listen("inproc://reqrep_proxy_multi_fe")

      proxy_backend = NNG::Socket::Req0.new
      proxy_backend.dial("inproc://reqrep_proxy_multi")

      client = NNG::Socket::Req0.new
      client.dial("inproc://reqrep_proxy_multi_fe")

      n = 5

      # Backend: process n requests
      task.async do
        n.times do
          msg = backend.receive
          backend.send("processed:#{msg.body}")
        end
      end

      # Proxy: forward n requests
      task.async do
        n.times do
          msg = proxy_frontend.receive
          proxy_backend.send(msg.body)
          reply = proxy_backend.receive
          proxy_frontend.send(reply.body)
        end
      end

      n.times do |i|
        client.send("job-#{i}")
        reply = client.receive
        assert_equal "processed:job-#{i}", reply.body
      end
    end
  end

  it "opens Req0 in raw mode" do
    sock = NNG::Socket::Req0.new(raw: true)
    refute_nil sock
  end

  it "opens Rep0 in raw mode" do
    sock = NNG::Socket::Rep0.new(raw: true)
    refute_nil sock
  end
end
