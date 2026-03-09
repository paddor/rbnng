$LOAD_PATH.unshift(File.expand_path('../../lib', __dir__))

require 'minitest/autorun'
require 'minitest/spec'
require 'async'
require 'nng'

# ZGuide Chapter 5 — Last Value Cache (LVC) Pattern
# A caching proxy sits between publishers and subscribers. It forwards
# every message and caches the last value per topic. Late-joining
# subscribers request a snapshot via a Req/Rep side-channel so they
# don't miss earlier state, then receive live updates via Pub/Sub.

describe 'Last Value Cache' do
  it 'replays last value per topic to late joiners' do
    cache = {}
    cached_values = []
    live_values = []

    Sync do |task|
      # --- Cache proxy sockets ---
      frontend = NNG::Socket::Sub0.new
      frontend.listen('inproc://zg_lvc_fe')

      backend = NNG::Socket::Pub0.new
      backend.listen('inproc://zg_lvc_be')

      snapshot = NNG::Socket::Rep0.new
      snapshot.listen('inproc://zg_lvc_snap')

      # Forwarder: caches last value per topic, forwards to subscribers
      forwarder = task.async do
        loop do
          msg = frontend.receive
          topic = msg.body.split(':').first
          cache[topic] = msg.body
          backend.send(msg.body)
          puts "  cache: stored #{msg.body}"
        end
      end

      # Snapshot server: replies with all cached values
      snap_server = task.async do
        loop do
          snapshot.receive
          snapshot.send(cache.values.join("\n"))
        end
      end

      # --- Publisher sends initial data ---
      pub = NNG::Socket::Pub0.new
      pub.dial('inproc://zg_lvc_fe')
      sleep 0.01

      pub.send('temp:72')
      pub.send('humidity:45')
      pub.send('temp:74') # overwrites temp:72 in cache
      sleep 0.05 # let forwarder process all messages

      # --- Late joiner: missed all three messages ---
      sub = NNG::Socket::Sub0.new
      sub.dial('inproc://zg_lvc_be')

      # Step 1: request snapshot of cached state
      req = NNG::Socket::Req0.new
      req.dial('inproc://zg_lvc_snap')
      req.send('SNAPSHOT')
      reply = req.receive
      cached_values.replace(reply.body.split("\n").sort)
      cached_values.each { |v| puts "  late joiner: cached #{v}" }

      sleep 0.01

      # Step 2: receive live updates going forward
      task.async { pub.send('temp:76') }
      msg = sub.receive
      live_values << msg.body
      puts "  late joiner: live #{msg.body}"

      forwarder.stop
      snap_server.stop
    end

    # Late joiner got the last value per topic (temp:72 was overwritten)
    assert_equal %w[humidity:45 temp:74], cached_values
    # And also received the subsequent live update
    assert_equal %w[temp:76], live_values
  end
end
