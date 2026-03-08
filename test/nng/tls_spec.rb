# frozen_string_literal: true

require 'minitest/autorun'
require 'minitest/spec'
require 'async'
require 'openssl'
require 'nng'

TLS_SPEC_PORT = [9000]

def next_tls_port
  TLS_SPEC_PORT[0] += 1
  TLS_SPEC_PORT[0]
end

def make_ca
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

def make_server_cert(ca_cert, ca_key, cn: '127.0.0.1')
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
  cert.add_extension(ef.create_extension('subjectAltName', "IP:127.0.0.1,DNS:localhost"))
  cert.sign(ca_key, OpenSSL::Digest::SHA256.new)
  [cert, key]
end

CA_CERT, CA_KEY = make_ca
SERVER_CERT, SERVER_KEY = make_server_cert(CA_CERT, CA_KEY)

describe 'TLS' do
  it 'req/rep over TLS with verify: false' do
    port = next_tls_port
    url = "tls+tcp://127.0.0.1:#{port}"

    Sync do |task|
      rep = NNG::Socket::Rep0.new
      rep.listen(url, cert: SERVER_CERT, key: SERVER_KEY)

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
    port = next_tls_port
    url = "tls+tcp://127.0.0.1:#{port}"

    Sync do |task|
      rep = NNG::Socket::Rep0.new
      rep.listen(url, cert: SERVER_CERT, key: SERVER_KEY)

      req = NNG::Socket::Req0.new
      req.dial(url, ca: CA_CERT, server_name: '127.0.0.1')

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
    port = next_tls_port
    url = "tls+tcp://127.0.0.1:#{port}"

    Sync do |task|
      rep = NNG::Socket::Rep0.new
      rep.listen(url, cert: SERVER_CERT.to_pem, key: SERVER_KEY.to_pem)

      req = NNG::Socket::Req0.new
      req.dial(url, ca: CA_CERT.to_pem, server_name: '127.0.0.1')

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
    key_file = Tempfile.new(['key', '.pem'])
    ca_file = Tempfile.new(['ca', '.pem'])

    cert_file.write(SERVER_CERT.to_pem)
    cert_file.flush
    key_file.write(SERVER_KEY.to_pem)
    key_file.flush
    ca_file.write(CA_CERT.to_pem)
    ca_file.flush

    port = next_tls_port
    url = "tls+tcp://127.0.0.1:#{port}"

    Sync do |task|
      rep = NNG::Socket::Rep0.new
      rep.listen(url,
                 cert: Pathname.new(cert_file.path),
                 key: Pathname.new(key_file.path))

      req = NNG::Socket::Req0.new
      req.dial(url,
               ca: Pathname.new(ca_file.path),
               server_name: '127.0.0.1')

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
    port = next_tls_port
    url = "tls+tcp://127.0.0.1:#{port}"

    Sync do |task|
      pub = NNG::Socket::Pub0.new
      pub.listen(url, cert: SERVER_CERT, key: SERVER_KEY)

      sub = NNG::Socket::Sub0.new
      sub.dial(url, verify: false)

      sleep 0.01

      task.async { pub.send('tls-broadcast') }
      msg = sub.receive
      assert_equal 'tls-broadcast', msg.body
    end
  end

  it 'server requires client cert (mutual TLS)' do
    client_cert, client_key = make_server_cert(CA_CERT, CA_KEY, cn: 'client')

    port = next_tls_port
    url = "tls+tcp://127.0.0.1:#{port}"

    Sync do |task|
      rep = NNG::Socket::Rep0.new
      rep.listen(url,
                 cert: SERVER_CERT, key: SERVER_KEY,
                 ca: CA_CERT, verify: true)

      req = NNG::Socket::Req0.new
      req.dial(url,
               cert: client_cert, key: client_key,
               ca: CA_CERT, server_name: '127.0.0.1')

      task.async do
        msg = rep.receive
        rep.send("mtls: #{msg.body}")
      end

      req.send('mutual')
      reply = req.receive
      assert_equal 'mtls: mutual', reply.body
    end
  end
end
