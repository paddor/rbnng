# frozen_string_literal: true

require 'minitest/autorun'
require 'minitest/spec'
require 'async'
require 'openssl'
require 'socket'
require 'tempfile'
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

def shannon_entropy(bytes)
  return 0.0 if bytes.empty?
  freq = Hash.new(0)
  bytes.each_byte { |b| freq[b] += 1 }
  len = bytes.bytesize.to_f
  freq.values.sum { |c| p_val = c / len; -p_val * Math.log2(p_val) }
end

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

  describe 'tcpdump encryption verification' do
    before do
      skip 'tcpdump not available' unless system('which tcpdump >/dev/null 2>&1')
      skip 'no permission for tcpdump' unless Process.uid == 0 || system('timeout 1 tcpdump -i any -c 1 -w /dev/null 2>/dev/null; test $? -ne 1')
    end

    it 'plaintext is visible in TCP capture but not in TLS capture' do
      canary = "CANARY_PLAINTEXT_MARKER_#{rand(1_000_000)}"

      # Capture plaintext TCP traffic
      tcp_port = next_tlsv_port
      tcp_url = "tcp://127.0.0.1:#{tcp_port}"
      tcp_pcap = Tempfile.new(['tcp', '.pcap'])

      tcp_pid = spawn('tcpdump', '-U', '-i', 'any', '-w', tcp_pcap.path,
                      "tcp port #{tcp_port}", '-c', '50',
                      [:out, :err] => '/dev/null')
      sleep 1

      Async do |task|
        rep = NNG::Socket::Rep0.new
        rep.listen(tcp_url)

        req = NNG::Socket::Req0.new
        req.dial(tcp_url)

        task.async do
          msg = rep.receive
          rep.send("re: #{msg.body}")
        end

        req.send(canary)
        req.receive
      end

      sleep 1
      Process.kill('TERM', tcp_pid)
      Process.wait(tcp_pid)

      # Capture TLS traffic
      tls_port = next_tlsv_port
      tls_url = "tls+tcp://127.0.0.1:#{tls_port}"
      tls_pcap = Tempfile.new(['tls', '.pcap'])

      tls_pid = spawn('tcpdump', '-U', '-i', 'any', '-w', tls_pcap.path,
                      "tcp port #{tls_port}", '-c', '50',
                      [:out, :err] => '/dev/null')
      sleep 1

      Async do |task|
        rep = NNG::Socket::Rep0.new
        rep.listen(tls_url, cert: TLSV_SERVER_CERT, key: TLSV_SERVER_KEY)

        req = NNG::Socket::Req0.new
        req.dial(tls_url, verify: false)

        task.async do
          msg = rep.receive
          rep.send("re: #{msg.body}")
        end

        req.send(canary)
        req.receive
      end

      sleep 1
      Process.kill('TERM', tls_pid)
      Process.wait(tls_pid)

      tcp_data = File.binread(tcp_pcap.path)
      tls_data = File.binread(tls_pcap.path)

      assert tcp_data.include?(canary), 'canary must be visible in plaintext TCP capture'
      refute tls_data.include?(canary), 'canary must NOT be visible in TLS capture'
    ensure
      tcp_pcap&.close!
      tls_pcap&.close!
    end

    it 'TLS traffic has higher Shannon entropy than plaintext' do
      payload = 'A' * 200

      # Plaintext exchange
      tcp_port = next_tlsv_port
      tcp_url = "tcp://127.0.0.1:#{tcp_port}"
      tcp_pcap = Tempfile.new(['tcp_ent', '.pcap'])

      tcp_pid = spawn('tcpdump', '-U', '-i', 'any', '-w', tcp_pcap.path,
                      "tcp port #{tcp_port}", '-c', '50',
                      [:out, :err] => '/dev/null')
      sleep 1

      Async do |task|
        rep = NNG::Socket::Rep0.new
        rep.listen(tcp_url)

        req = NNG::Socket::Req0.new
        req.dial(tcp_url)

        task.async do
          msg = rep.receive
          rep.send(msg.body)
        end

        req.send(payload)
        req.receive
      end

      sleep 1
      Process.kill('TERM', tcp_pid)
      Process.wait(tcp_pid)

      # TLS exchange
      tls_port = next_tlsv_port
      tls_url = "tls+tcp://127.0.0.1:#{tls_port}"
      tls_pcap = Tempfile.new(['tls_ent', '.pcap'])

      tls_pid = spawn('tcpdump', '-U', '-i', 'any', '-w', tls_pcap.path,
                      "tcp port #{tls_port}", '-c', '50',
                      [:out, :err] => '/dev/null')
      sleep 1

      Async do |task|
        rep = NNG::Socket::Rep0.new
        rep.listen(tls_url, cert: TLSV_SERVER_CERT, key: TLSV_SERVER_KEY)

        req = NNG::Socket::Req0.new
        req.dial(tls_url, verify: false)

        task.async do
          msg = rep.receive
          rep.send(msg.body)
        end

        req.send(payload)
        req.receive
      end

      sleep 1
      Process.kill('TERM', tls_pid)
      Process.wait(tls_pid)

      # Skip pcap global header (24 bytes)
      tcp_app_data = File.binread(tcp_pcap.path)[24..] || ''
      tls_app_data = File.binread(tls_pcap.path)[24..] || ''

      skip 'insufficient capture data' if tcp_app_data.bytesize < 100 || tls_app_data.bytesize < 100

      tcp_entropy = shannon_entropy(tcp_app_data)
      tls_entropy = shannon_entropy(tls_app_data)

      assert tls_entropy > tcp_entropy,
             "TLS entropy (#{tls_entropy}) should exceed TCP entropy (#{tcp_entropy})"
    ensure
      tcp_pcap&.close!
      tls_pcap&.close!
    end
  end

  describe 'raw TCP negative test' do
    it 'raw TCP socket cannot read TLS plaintext' do
      canary = "RAW_TCP_CANARY_#{rand(1_000_000)}"
      port = next_tlsv_port
      url = "tls+tcp://127.0.0.1:#{port}"

      raw_bytes = nil

      Async do |task|
        rep = NNG::Socket::Rep0.new
        rep.listen(url, cert: TLSV_SERVER_CERT, key: TLSV_SERVER_KEY)

        # Connect a raw TCP socket
        task.async do
          sleep 0.1
          sock = TCPSocket.new('127.0.0.1', port)
          sock.setsockopt(Socket::IPPROTO_TCP, Socket::TCP_NODELAY, 1)
          # Read whatever the TLS server sends (handshake bytes)
          raw_bytes = sock.read_nonblock(4096)
        rescue IO::WaitReadable
          IO.select([sock], nil, nil, 1)
          raw_bytes = sock.read_nonblock(4096) rescue ''
        rescue
          raw_bytes = ''
        ensure
          sock&.close
        end

        # Also do a real TLS exchange so the server has traffic
        req = NNG::Socket::Req0.new
        req.dial(url, verify: false)

        task.async do
          msg = rep.receive
          rep.send("re: #{msg.body}")
        end

        req.send(canary)
        req.receive
      end

      refute_nil raw_bytes
      refute raw_bytes.include?(canary),
             'canary must NOT appear in raw TCP bytes from a TLS port'
    end
  end
end
