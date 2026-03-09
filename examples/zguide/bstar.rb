$LOAD_PATH.unshift(File.expand_path('../../lib', __dir__))

require 'minitest/autorun'
require 'minitest/spec'
require 'async'
require 'nng'

# ZGuide Chapter 4 — Binary Star Pattern
# Active/passive high-availability pair. The primary server handles
# client requests while exchanging heartbeats with a backup. When
# the primary fails, the backup detects the loss and takes over.
# The client retries against the backup on timeout.

describe 'Binary Star' do
  it 'backup takes over when primary fails' do
    primary_addr = 'tcp://127.0.0.1:15560'
    backup_addr  = 'tcp://127.0.0.1:15561'
    served_by = []

    Async do |task|
      # --- Heartbeat channel (primary → backup) ---
      hb_pub = NNG::Socket::Pub0.new
      hb_pub.listen('inproc://bstar_hb')

      hb_sub = NNG::Socket::Sub0.new(prefix: 'HB')
      hb_sub.recv_timeout = 0.3
      hb_sub.dial('inproc://bstar_hb')

      # --- Primary server ---
      primary_rep = NNG::Socket::Rep0.new
      primary_rep.listen(primary_addr)

      primary_hb = task.async do
        loop do
          hb_pub.send('HB')
          sleep 0.1
        end
      end

      primary_server = task.async do
        loop do
          msg = primary_rep.receive
          primary_rep.send("primary:#{msg.body}")
          puts "  primary: served #{msg.body}"
        end
      end

      # --- Backup server: monitors heartbeats, serves after failover ---
      backup_rep = NNG::Socket::Rep0.new
      backup_rep.listen(backup_addr)

      backup_server = task.async do
        # Phase 1: passive — wait for primary failure
        loop do
          hb_sub.receive
        rescue Timeout::Error
          puts "  backup: primary heartbeat lost — taking over!"
          break
        end

        # Phase 2: active — serve client requests
        loop do
          msg = backup_rep.receive
          backup_rep.send("backup:#{msg.body}")
          puts "  backup: served #{msg.body}"
        end
      end

      sleep 0.01

      # --- Client helper: try primary, fall back to backup on timeout ---
      send_request = lambda do |body|
        req = NNG::Socket::Req0.new
        req.send_timeout = 0.3
        req.recv_timeout = 0.3
        req.dial(primary_addr)
        req.send(body)
        reply = req.receive
        req.close
        reply.body
      rescue Timeout::Error, NNG::Error
        req&.close
        req = NNG::Socket::Req0.new
        req.recv_timeout = 1.0
        req.dial(backup_addr)
        req.send(body)
        reply = req.receive
        req.close
        reply.body
      end

      # Phase 1: primary handles requests
      served_by << send_request.call('req-1')
      served_by << send_request.call('req-2')

      # Primary crashes
      puts "  --- primary crashes ---"
      primary_hb.stop
      primary_server.stop
      primary_rep.close

      # Phase 2: client fails over to backup
      served_by << send_request.call('req-3')
      served_by << send_request.call('req-4')

      backup_server.stop
    end

    puts "  responses: #{served_by.inspect}"
    assert_equal 'primary:req-1', served_by[0]
    assert_equal 'primary:req-2', served_by[1]
    assert_equal 'backup:req-3', served_by[2]
    assert_equal 'backup:req-4', served_by[3]
  end
end
