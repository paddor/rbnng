$LOAD_PATH.unshift(File.expand_path('../../lib', __dir__))

require 'minitest/autorun'
require 'minitest/spec'
require 'async'
require 'nng'

# ZGuide Chapter 5 — Clone Pattern
# Reliable pub-sub state synchronization. A server maintains a KV store,
# publishing every mutation with a sequence number. Late-joining clients
# request a snapshot (Req/Rep), then subscribe to live updates (Pub/Sub),
# applying only updates newer than the snapshot sequence.

describe 'Clone' do
  it 'synchronizes state to a late-joining client' do
    server_kv = {}
    client_kv = {}

    Sync do |task|
      seq = 0

      # --- Server sockets ---
      publisher = NNG::Socket::Pub0.new
      publisher.listen('inproc://clone_pub')

      snapshot_rep = NNG::Socket::Rep0.new
      snapshot_rep.listen('inproc://clone_snap')

      # Publish a KV update: "seq:key=value"
      publish = lambda do |key, value|
        seq += 1
        server_kv[key] = value
        publisher.send("#{seq}:#{key}=#{value}")
        puts "  server: published #{key}=#{value} (seq #{seq})"
      end

      # Snapshot server: replies with "seq\nkey=value\nkey=value\n..."
      snap_server = task.async do
        loop do
          snapshot_rep.receive
          body = "#{seq}\n" + server_kv.map { |k, v| "#{k}=#{v}" }.join("\n")
          snapshot_rep.send(body)
        end
      end

      # Server publishes initial state
      publish.call('name', 'Alice')
      publish.call('age', '30')
      publish.call('name', 'Bob') # overwrites name
      sleep 0.05

      # --- Late-joining client ---

      # Step 1: request snapshot
      req = NNG::Socket::Req0.new
      req.dial('inproc://clone_snap')
      req.send('SNAP')
      reply = req.receive
      lines = reply.body.split("\n")
      snap_seq = lines.shift.to_i

      lines.each do |line|
        k, v = line.split('=', 2)
        client_kv[k] = v
      end
      puts "  client: snapshot at seq #{snap_seq}: #{client_kv.inspect}"

      # Step 2: subscribe for live updates
      sub = NNG::Socket::Sub0.new
      sub.dial('inproc://clone_pub')
      sleep 0.01

      # Server publishes more updates
      task.async do
        publish.call('age', '31')
        publish.call('city', 'NYC')
      end

      # Client applies updates newer than snapshot
      2.times do
        msg = sub.receive
        msg_seq, rest = msg.body.split(':', 2)
        if msg_seq.to_i <= snap_seq
          puts "  client: skipping old update (seq #{msg_seq})"
          next
        end
        k, v = rest.split('=', 2)
        client_kv[k] = v
        puts "  client: applied #{k}=#{v} (seq #{msg_seq})"
      end

      snap_server.stop
    end

    puts "  server state: #{server_kv.inspect}"
    puts "  client state: #{client_kv.inspect}"
    assert_equal server_kv, client_kv
  end
end
