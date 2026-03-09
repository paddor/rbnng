$LOAD_PATH.unshift(File.expand_path('../../lib', __dir__))

require 'minitest/autorun'
require 'minitest/spec'
require 'async'
require 'nng'

# ZGuide Chapter 1 — Pipeline (Divide and Conquer)
# A ventilator pushes work items to workers via Push0/Pull0.
# Workers process items (simulated delay) and push results to a sink.
# Demonstrates fan-out/fan-in with load balancing across workers.

describe 'Pipeline Workers' do
  it 'distributes work across multiple workers and collects results' do
    results = []
    worker_counts = Hash.new(0)
    n = 20

    Async do |task|
      ventilator = NNG::Socket::Push0.new
      ventilator.listen('inproc://zg_ventilator')

      sink = NNG::Socket::Pull0.new
      sink.listen('inproc://zg_sink')

      # Start 3 workers
      3.times do |id|
        task.async do
          pull = NNG::Socket::Pull0.new
          pull.dial('inproc://zg_ventilator')

          push = NNG::Socket::Push0.new
          push.dial('inproc://zg_sink')

          loop do
            msg = pull.receive
            break if msg.body == 'END'
            sleep msg.body.to_i / 1000.0 # simulate work
            push.send("worker-#{id}:#{msg.body}")
          end
        end
      end

      sleep 0.01

      # Ventilator sends work items in its own fiber so the main
      # fiber can concurrently drain the sink (avoids back-pressure
      # deadlock when buffers fill).
      task.async do
        n.times { ventilator.send((rand(5) + 1).to_s) }
        3.times { ventilator.send('END') }
      end

      # Sink collects results
      n.times do
        msg = sink.receive
        results << msg.body
        worker_id = msg.body.split(':').first
        worker_counts[worker_id] += 1
        puts "  sink: received #{msg.body}"
      end
    end

    puts "  summary: #{results.size} results from #{worker_counts.size} workers"
    worker_counts.each { |id, count| puts "    #{id}: #{count} items" }

    assert_equal n, results.size
    assert worker_counts.size > 1, 'expected multiple workers to participate'
  end
end
