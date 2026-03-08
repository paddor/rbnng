# frozen_string_literal: true

require 'minitest/autorun'
require 'minitest/spec'
require 'async'
require 'openssl'
require 'nng'

TLSV_PORT = [9100]

def next_tlsv_port
  TLSV_PORT[0] += 1
  TLSV_PORT[0]
end

def make_tlsv_ca
  key = OpenSSL::PKey::RSA.new(2048)
  cert = OpenSSL::X509::Certificate.new
  cert.version = 2
  cert.serial = 1
  cert.subject = OpenSSL::X509::Name.parse('/CN=TestCA')
  cert.issuer = cert.subject
  cert.public_key = key.public_key
  cert.not_before = Time.now - 3600
  cert.not_after = Time.now + 3600

  ef = OpenSSL::X509::ExtensionFactory.new
  ef.subject_certificate = cert
  ef.issuer_certificate = cert
  cert.add_extension(ef.create_extension('basicConstraints', 'CA:TRUE', true))
  cert.add_extension(ef.create_extension('subjectKeyIdentifier', 'hash'))
  cert.sign(key, OpenSSL::Digest::SHA256.new)
  [cert, key]
end

def make_tlsv_server_cert(ca_cert, ca_key, cn: '127.0.0.1')
  key = OpenSSL::PKey::RSA.new(2048)
  cert = OpenSSL::X509::Certificate.new
  cert.version = 2
  cert.serial = 2
  cert.subject = OpenSSL::X509::Name.parse("/CN=#{cn}")
  cert.issuer = ca_cert.subject
  cert.public_key = key.public_key
  cert.not_before = Time.now - 3600
  cert.not_after = Time.now + 3600

  ef = OpenSSL::X509::ExtensionFactory.new
  ef.subject_certificate = cert
  ef.issuer_certificate = ca_cert
  cert.add_extension(ef.create_extension('subjectAltName', 'IP:127.0.0.1,DNS:localhost'))
  cert.sign(ca_key, OpenSSL::Digest::SHA256.new)
  [cert, key]
end

TLSV_CA_CERT, TLSV_CA_KEY = make_tlsv_ca
TLSV_SERVER_CERT, TLSV_SERVER_KEY = make_tlsv_server_cert(TLSV_CA_CERT, TLSV_CA_KEY)

describe 'TLS verification' do
  describe 'pipe introspection' do
    it 'Message#pipe returns a Pipe for received messages' do
      port = next_tlsv_port
      url = "tls+tcp://127.0.0.1:#{port}"

      Async do |task|
        rep = NNG::Socket::Rep0.new
        rep.listen(url, cert: TLSV_SERVER_CERT, key: TLSV_SERVER_KEY)

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
      port = next_tlsv_port
      url = "tls+tcp://127.0.0.1:#{port}"

      Async do |task|
        rep = NNG::Socket::Rep0.new
        rep.listen(url, cert: TLSV_SERVER_CERT, key: TLSV_SERVER_KEY)

        req = NNG::Socket::Req0.new
        req.dial(url, ca: TLSV_CA_CERT, server_name: '127.0.0.1')

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
      port = next_tlsv_port
      url = "tls+tcp://127.0.0.1:#{port}"

      Async do |task|
        rep = NNG::Socket::Rep0.new
        rep.listen(url, cert: TLSV_SERVER_CERT, key: TLSV_SERVER_KEY)

        req = NNG::Socket::Req0.new
        req.dial(url, ca: TLSV_CA_CERT, server_name: '127.0.0.1')

        task.async do
          msg = rep.receive
          rep.send("cn: #{msg.body}")
        end

        req.send('who')
        reply = req.receive

        assert_equal '127.0.0.1', reply.pipe.tls_peer_cn
      end
    end

    it 'tls_peer_cn returns peer CN in mutual TLS' do
      client_cert, client_key = make_tlsv_server_cert(TLSV_CA_CERT, TLSV_CA_KEY, cn: 'test-client')

      port = next_tlsv_port
      url = "tls+tcp://127.0.0.1:#{port}"

      Async do |task|
        rep = NNG::Socket::Rep0.new
        rep.listen(url,
                   cert: TLSV_SERVER_CERT, key: TLSV_SERVER_KEY,
                   ca: TLSV_CA_CERT, verify: true)

        req = NNG::Socket::Req0.new
        req.dial(url,
                 cert: client_cert, key: client_key,
                 ca: TLSV_CA_CERT, server_name: '127.0.0.1')

        received_msg = nil
        task.async do
          received_msg = rep.receive
          rep.send("mtls: #{received_msg.body}")
        end

        req.send('mutual')
        reply = req.receive

        # Client sees server CN
        assert_equal '127.0.0.1', reply.pipe.tls_peer_cn

        # Server sees client CN
        assert_equal 'test-client', received_msg.pipe.tls_peer_cn
      end
    end
  end
end
