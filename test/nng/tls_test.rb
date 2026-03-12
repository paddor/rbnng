# frozen_string_literal: true

require_relative '../test_helper'
require 'async'
require 'localhost'

AUTH = Localhost::Authority.fetch
PORT = (9000..).to_enum

describe 'TLS' do
  it 'req/rep over TLS with verify: false' do
    url = "tls+tcp://127.0.0.1:#{PORT.next}"

    Sync do |task|
      rep = NNG::Socket::Rep0.new
      rep.listen(url, cert: AUTH.certificate, key: AUTH.key)

      req = NNG::Socket::Req0.new
      req.dial(url, verify: false)

      task.async do
        msg = rep.receive
        rep.send("re: #{msg.body}")
      end

      req.send('hello')
      reply = req.receive
      assert_equal 're: hello', reply.body
    end
  end

  it 'req/rep over TLS with CA verification' do
    url = "tls+tcp://127.0.0.1:#{PORT.next}"

    Sync do |task|
      rep = NNG::Socket::Rep0.new
      rep.listen(url, cert: AUTH.certificate, key: AUTH.key)

      req = NNG::Socket::Req0.new
      req.dial(url, ca: AUTH.issuer.certificate, server_name: 'localhost')

      task.async do
        msg = rep.receive
        rep.send("verified: #{msg.body}")
      end

      req.send('secure')
      reply = req.receive
      assert_equal 'verified: secure', reply.body
    end
  end

  it 'accepts PEM strings directly' do
    url = "tls+tcp://127.0.0.1:#{PORT.next}"

    Sync do |task|
      rep = NNG::Socket::Rep0.new
      rep.listen(url, cert: AUTH.certificate.to_pem,
                      key:  AUTH.key.to_pem)

      req = NNG::Socket::Req0.new
      req.dial(url, ca:          AUTH.issuer.certificate.to_pem,
                    server_name: 'localhost')

      task.async do
        msg = rep.receive
        rep.send("pem: #{msg.body}")
      end

      req.send('string')
      reply = req.receive
      assert_equal 'pem: string', reply.body
    end
  end

  it 'accepts Pathname objects' do
    require 'tempfile'

    cert_file = Tempfile.new(['cert', '.pem'])
    key_file  = Tempfile.new(['key', '.pem'])
    ca_file   = Tempfile.new(['ca', '.pem'])

    cert_file.write(AUTH.certificate.to_pem)
    cert_file.flush
    key_file.write(AUTH.key.to_pem)
    key_file.flush
    ca_file.write(AUTH.issuer.certificate.to_pem)
    ca_file.flush

    url = "tls+tcp://127.0.0.1:#{PORT.next}"

    Sync do |task|
      rep = NNG::Socket::Rep0.new
      rep.listen(url, cert: Pathname.new(cert_file.path),
                      key:  Pathname.new(key_file.path))

      req = NNG::Socket::Req0.new
      req.dial(url, ca:          Pathname.new(ca_file.path),
                    server_name: 'localhost')

      task.async do
        msg = rep.receive
        rep.send("path: #{msg.body}")
      end

      req.send('file')
      reply = req.receive
      assert_equal 'path: file', reply.body
    end
  ensure
    cert_file&.close!
    key_file&.close!
    ca_file&.close!
  end

  it 'pub/sub over TLS' do
    url = "tls+tcp://127.0.0.1:#{PORT.next}"

    Sync do |task|
      pub = NNG::Socket::Pub0.new
      pub.listen(url, cert: AUTH.certificate, key: AUTH.key)

      sub = NNG::Socket::Sub0.new
      sub.dial(url, verify: false)

      sleep 0.01

      task.async { pub.send('tls-broadcast') }
      msg = sub.receive
      assert_equal 'tls-broadcast', msg.body
    end
  end

  it 'server requires client cert (mutual TLS)' do
    client = Localhost::Authority.new('client')
    url    = "tls+tcp://127.0.0.1:#{PORT.next}"

    Sync do |task|
      rep = NNG::Socket::Rep0.new
      rep.listen(url, cert: AUTH.certificate, key: AUTH.key,
                      ca:   AUTH.issuer.certificate, verify: true)

      req = NNG::Socket::Req0.new
      req.dial(url, cert:        client.certificate, key: client.key,
                    ca:          AUTH.issuer.certificate,
                    server_name: 'localhost')

      task.async do
        msg = rep.receive
        rep.send("mtls: #{msg.body}")
      end

      req.send('mutual')
      reply = req.receive
      assert_equal 'mtls: mutual', reply.body
    end
  end

  describe 'pipe introspection' do
    it 'Message#pipe returns a Pipe for received messages' do
      url = "tls+tcp://127.0.0.1:#{PORT.next}"

      Sync do |task|
        rep = NNG::Socket::Rep0.new
        rep.listen(url, cert: AUTH.certificate, key: AUTH.key)

        req = NNG::Socket::Req0.new
        req.dial(url, verify: false)

        task.async do
          msg = rep.receive
          rep.send("re: #{msg.body}")
        end

        req.send('hello')
        reply = req.receive

        refute_nil reply.pipe
        assert_instance_of NNG::Pipe, reply.pipe
        assert_kind_of Integer, reply.pipe.id
      end
    end

    it 'tls_verified? is true when CA verification succeeds' do
      url = "tls+tcp://127.0.0.1:#{PORT.next}"

      Sync do |task|
        rep = NNG::Socket::Rep0.new
        rep.listen(url, cert: AUTH.certificate, key: AUTH.key)

        req = NNG::Socket::Req0.new
        req.dial(url, ca: AUTH.issuer.certificate, server_name: 'localhost')

        task.async do
          msg = rep.receive
          rep.send("verified: #{msg.body}")
        end

        req.send('check')
        reply = req.receive

        assert reply.pipe.tls_verified?, 'expected pipe to report TLS verified'
      end
    end

    it 'tls_peer_cn returns the server CN when verified' do
      url = "tls+tcp://127.0.0.1:#{PORT.next}"

      Sync do |task|
        rep = NNG::Socket::Rep0.new
        rep.listen(url, cert: AUTH.certificate, key: AUTH.key)

        req = NNG::Socket::Req0.new
        req.dial(url, ca: AUTH.issuer.certificate, server_name: 'localhost')

        task.async do
          msg = rep.receive
          rep.send("cn: #{msg.body}")
        end

        req.send('who')
        reply = req.receive

        assert_equal 'localhost', reply.pipe.tls_peer_cn
      end
    end

    it 'tls_peer_cn returns peer CN in mutual TLS' do
      client = Localhost::Authority.new('test-client')
      url    = "tls+tcp://127.0.0.1:#{PORT.next}"

      Sync do |task|
        rep = NNG::Socket::Rep0.new
        rep.listen(url, cert: AUTH.certificate, key: AUTH.key,
                        ca:   AUTH.issuer.certificate, verify: true)

        req = NNG::Socket::Req0.new
        req.dial(url, cert:        client.certificate, key: client.key,
                      ca:          AUTH.issuer.certificate,
                      server_name: 'localhost')

        received_msg = nil
        task.async do
          received_msg = rep.receive
          rep.send("mtls: #{received_msg.body}")
        end

        req.send('mutual')
        reply = req.receive

        # Client sees server CN
        assert_equal 'localhost', reply.pipe.tls_peer_cn

        # Server sees client CN
        assert_equal 'test-client', received_msg.pipe.tls_peer_cn
      end
    end
  end
end
