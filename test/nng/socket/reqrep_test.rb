# frozen_string_literal: true

require_relative '../../test_helper'
require 'async'

describe 'Req0 / Rep0' do
  it 'completes a request/reply roundtrip' do
    Sync do |task|
      rep = NNG::Socket::Rep0.new
      rep.listen('inproc://reqrep_basic')

      req = NNG::Socket::Req0.new
      req.dial('inproc://reqrep_basic')

      task.async do
        request = rep.receive
        assert_equal 'ping', request.body
        rep.send('pong')
      end

      req.send('ping')
      reply = req.receive

      assert_equal 'pong', reply.body
    end
  end

  it 'handles multiple sequential requests' do
    Sync do |task|
      rep = NNG::Socket::Rep0.new
      rep.listen('inproc://reqrep_sequential')

      req = NNG::Socket::Req0.new
      req.dial('inproc://reqrep_sequential')

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

  it 'serves multiple clients' do
    Sync do |task|
      rep = NNG::Socket::Rep0.new
      rep.listen('inproc://reqrep_multi_client')

      clients = 3.times.map do |i|
        req = NNG::Socket::Req0.new
        req.dial('inproc://reqrep_multi_client')
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

  it 'proxies a request through a middle rep/req pair' do
    Sync do |task|
      # Backend: the service that does the actual work
      backend = NNG::Socket::Rep0.new
      backend.listen('inproc://reqrep_backend')

      # Proxy: receives from frontend, forwards to backend, returns reply
      proxy_frontend = NNG::Socket::Rep0.new
      proxy_frontend.listen('inproc://reqrep_proxy')

      proxy_backend = NNG::Socket::Req0.new
      proxy_backend.dial('inproc://reqrep_backend')

      # Client
      client = NNG::Socket::Req0.new
      client.dial('inproc://reqrep_proxy')

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

      client.send('hello')
      reply = client.receive

      assert_equal 'backend:hello', reply.body
    end
  end

  it 'proxies multiple requests through a middle rep/req pair' do
    Sync do |task|
      backend = NNG::Socket::Rep0.new
      backend.listen('inproc://reqrep_proxy_multi')

      proxy_frontend = NNG::Socket::Rep0.new
      proxy_frontend.listen('inproc://reqrep_proxy_multi_fe')

      proxy_backend = NNG::Socket::Req0.new
      proxy_backend.dial('inproc://reqrep_proxy_multi')

      client = NNG::Socket::Req0.new
      client.dial('inproc://reqrep_proxy_multi_fe')

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

  it 'single-hop raw proxy via forward' do
    Sync do |task|
      # Backend
      backend = NNG::Socket::Rep0.new
      backend.listen('inproc://raw_proxy_single')

      # Proxy: raw rep (frontend) + raw req (backend)
      proxy_fe = NNG::Socket::Rep0.new(raw: true)
      proxy_fe.listen('inproc://raw_proxy_single_fe')

      proxy_be = NNG::Socket::Req0.new(raw: true)
      proxy_be.dial('inproc://raw_proxy_single')

      # Client
      client = NNG::Socket::Req0.new
      client.dial('inproc://raw_proxy_single_fe')

      # Backend echoes with prefix
      task.async do
        msg = backend.receive
        backend.send("echo:#{msg.body}")
      end

      # Stateless proxy: forward in both directions
      task.async do
        msg = proxy_fe.receive
        proxy_be.forward(msg)
        reply = proxy_be.receive
        proxy_fe.forward(reply)
      end

      client.send('hello')
      reply = client.receive

      assert_equal 'echo:hello', reply.body
    end
  end

  it 'multi-hop raw proxy via forward' do
    Sync do |task|
      # Backend
      backend = NNG::Socket::Rep0.new
      backend.listen('inproc://raw_proxy_multi_hop_be')

      # Hop 2: raw rep + raw req
      hop2_fe = NNG::Socket::Rep0.new(raw: true)
      hop2_fe.listen('inproc://raw_proxy_multi_hop2')

      hop2_be = NNG::Socket::Req0.new(raw: true)
      hop2_be.dial('inproc://raw_proxy_multi_hop_be')

      # Hop 1: raw rep + raw req
      hop1_fe = NNG::Socket::Rep0.new(raw: true)
      hop1_fe.listen('inproc://raw_proxy_multi_hop1')

      hop1_be = NNG::Socket::Req0.new(raw: true)
      hop1_be.dial('inproc://raw_proxy_multi_hop2')

      # Client
      client = NNG::Socket::Req0.new
      client.dial('inproc://raw_proxy_multi_hop1')

      # Backend
      task.async do
        msg = backend.receive
        backend.send("hop2:#{msg.body}")
      end

      # Hop 2 — stateless forward
      task.async do
        msg = hop2_fe.receive
        hop2_be.forward(msg)
        reply = hop2_be.receive
        hop2_fe.forward(reply)
      end

      # Hop 1 — stateless forward
      task.async do
        msg = hop1_fe.receive
        hop1_be.forward(msg)
        reply = hop1_be.receive
        hop1_fe.forward(reply)
      end

      client.send('hello')
      reply = client.receive

      assert_equal 'hop2:hello', reply.body
    end
  end

  it 'multi-hop raw proxy handles multiple sequential requests' do
    Sync do |task|
      backend = NNG::Socket::Rep0.new
      backend.listen('inproc://raw_multi_hop_seq_be')

      hop2_fe = NNG::Socket::Rep0.new(raw: true)
      hop2_fe.listen('inproc://raw_multi_hop_seq_h2')

      hop2_be = NNG::Socket::Req0.new(raw: true)
      hop2_be.dial('inproc://raw_multi_hop_seq_be')

      hop1_fe = NNG::Socket::Rep0.new(raw: true)
      hop1_fe.listen('inproc://raw_multi_hop_seq_h1')

      hop1_be = NNG::Socket::Req0.new(raw: true)
      hop1_be.dial('inproc://raw_multi_hop_seq_h2')

      client = NNG::Socket::Req0.new
      client.dial('inproc://raw_multi_hop_seq_h1')

      n = 5

      task.async do
        n.times do
          msg = backend.receive
          backend.send("re:#{msg.body}")
        end
      end

      task.async do
        n.times do
          msg = hop2_fe.receive
          hop2_be.forward(msg)
          reply = hop2_be.receive
          hop2_fe.forward(reply)
        end
      end

      task.async do
        n.times do
          msg = hop1_fe.receive
          hop1_be.forward(msg)
          reply = hop1_be.receive
          hop1_fe.forward(reply)
        end
      end

      n.times do |i|
        client.send("msg-#{i}")
        reply = client.receive
        assert_equal "re:msg-#{i}", reply.body
      end
    end
  end

  it 'raw proxy preserves message header across hops' do
    Sync do |task|
      backend = NNG::Socket::Rep0.new(raw: true)
      backend.listen('inproc://raw_header_check_be')

      proxy_fe = NNG::Socket::Rep0.new(raw: true)
      proxy_fe.listen('inproc://raw_header_check_fe')

      proxy_be = NNG::Socket::Req0.new(raw: true)
      proxy_be.dial('inproc://raw_header_check_be')

      client = NNG::Socket::Req0.new
      client.dial('inproc://raw_header_check_fe')

      # Backend in raw mode: verify header is non-empty (contains routing info)
      task.async do
        msg = backend.receive
        refute_empty msg.header
        backend.forward(msg)
      end

      task.async do
        msg = proxy_fe.receive
        refute_empty msg.header
        proxy_be.forward(msg)
        reply = proxy_be.receive
        proxy_fe.forward(reply)
      end

      client.send('check')
      reply = client.receive

      assert_equal 'check', reply.body
    end
  end

  it 'opens Req0 in raw mode' do
    sock = NNG::Socket::Req0.new(raw: true)
    refute_nil sock
  end

  it 'opens Rep0 in raw mode' do
    sock = NNG::Socket::Rep0.new(raw: true)
    refute_nil sock
  end
end
