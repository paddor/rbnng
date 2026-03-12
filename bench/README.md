# Benchmark Results

NNG 1.10.0 | Ruby 4.0.1 +YJIT | Linux x86_64

## Throughput (push/pull, iterations/s)

### Async (fibers)

| Size | inproc | abstract | ipc | tcp |
|------|--------|----------|-----|-----|
| 64B | 47.3k | 14.3k | 13.3k | 8.4k |
| 256B | 42.2k | 13.7k | 13.9k | 7.3k |
| 1024B | 45.2k | 12.2k | 11.5k | 7.8k |
| 4096B | 33.2k | 8.8k | 8.2k | 6.8k |

### Threads

| Size | inproc | abstract | ipc | tcp |
|------|--------|----------|-----|-----|
| 64B | 41.7k | 15.4k | 16.6k | 10.1k |
| 256B | 36.4k | 16.0k | 15.7k | 9.4k |
| 1024B | 37.1k | 12.7k | 13.8k | 8.3k |
| 4096B | 33.2k | 9.2k | 8.9k | 7.2k |

## Latency (req/rep roundtrip)

### Async (fibers)

| Transport | roundtrips/s | latency |
|-----------|-------------|---------|
| inproc | 17.5k | 57 µs |
| abstract | 5.6k | 180 µs |
| ipc | 6.5k | 155 µs |
| tcp | 4.9k | 204 µs |

### Threads

| Transport | roundtrips/s | latency |
|-----------|-------------|---------|
| inproc | 3.8k | 260 µs |
| abstract | 3.9k | 256 µs |
| ipc | 3.7k | 272 µs |
| tcp | 3.5k | 287 µs |

## Notes

- All benchmarks run with `ruby --yjit`
- Throughput measures one-way push/pull (no reply needed)
- Latency measures full req/rep roundtrip
- Async uses Ruby fibers via the [async](https://github.com/socketry/async) gem
- Threads spawn a new `Thread` per iteration for the responder
- Async is ~4.6x faster for inproc latency due to cheap fiber switching

## Running

```sh
bundle exec ruby bench/async/throughput.rb
bundle exec ruby bench/async/latency.rb
bundle exec ruby bench/threads/throughput.rb
bundle exec ruby bench/threads/latency.rb
```
