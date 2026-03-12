# Benchmark Results

NNG 1.10.0 | Ruby 4.0.1 +YJIT | Linux x86_64

## Throughput (push/pull, iterations/s)

### Async (fibers)

| Size | inproc | ipc | tcp |
|------|--------|-----|-----|
| 64B | 36.1k | 14.9k | 8.0k |
| 256B | 33.3k | 14.1k | 7.5k |
| 1024B | 33.1k | 11.6k | 7.6k |
| 4096B | 42.2k | 8.2k | 8.6k |

### Threads

| Size | inproc | ipc | tcp |
|------|--------|-----|-----|
| 64B | 40.2k | 16.4k | 9.0k |
| 256B | 37.4k | 14.6k | 8.6k |
| 1024B | 38.1k | 14.1k | 8.5k |
| 4096B | 35.6k | 8.8k | 7.8k |

## Latency (req/rep roundtrip)

### Async (fibers)

| Transport | roundtrips/s | latency |
|-----------|-------------|---------|
| inproc | 18.4k | 54 µs |
| ipc | 6.3k | 160 µs |
| tcp | 5.1k | 195 µs |

### Threads

| Transport | roundtrips/s | latency |
|-----------|-------------|---------|
| inproc | 4.4k | 225 µs |
| ipc | 3.5k | 288 µs |
| tcp | 3.4k | 296 µs |

## Notes

- All benchmarks run with `ruby --yjit`
- Throughput measures one-way push/pull (no reply needed)
- Latency measures full req/rep roundtrip
- Async uses Ruby fibers via the [async](https://github.com/socketry/async) gem
- Threads spawn a new `Thread` per iteration for the responder
- Async is ~4.2x faster for inproc latency due to cheap fiber switching
- For throughput, threads are slightly faster on inproc due to lower push/pull scheduling overhead

## Running

```sh
bundle exec ruby bench/async/throughput.rb
bundle exec ruby bench/async/latency.rb
bundle exec ruby bench/threads/throughput.rb
bundle exec ruby bench/threads/latency.rb
```
