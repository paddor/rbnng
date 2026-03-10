# Benchmark Results

NNG 1.10.0 | Ruby 4.0.1 | Linux x86_64

## Throughput (push/pull, iterations/s)

### Async (fibers)

| Size | inproc | ipc | tcp |
|------|--------|-----|-----|
| 64B | 32.7k | 10.3k | 8.7k |
| 256B | 28.0k | 11.7k | 7.6k |
| 1024B | 31.4k | 10.3k | 7.0k |
| 4096B | 32.4k | 8.1k | 6.7k |

### Threads

| Size | inproc | ipc | tcp |
|------|--------|-----|-----|
| 64B | 37.8k | 17.7k | 7.2k |
| 256B | 38.8k | 17.6k | 9.0k |
| 1024B | 38.6k | 16.6k | 8.9k |
| 4096B | 37.8k | 12.2k | 7.2k |

## Latency (req/rep roundtrip)

### Async (fibers)

| Transport | roundtrips/s | latency |
|-----------|-------------|---------|
| inproc | 13.9k | 72 µs |
| ipc | 5.8k | 172 µs |
| tcp | 3.6k | 280 µs |

### Threads

| Transport | roundtrips/s | latency |
|-----------|-------------|---------|
| inproc | 5.1k | 198 µs |
| ipc | 4.3k | 231 µs |
| tcp | 3.7k | 273 µs |

## Notes

- Throughput measures one-way push/pull (no reply needed)
- Latency measures full req/rep roundtrip
- Async uses Ruby fibers via the [async](https://github.com/socketry/async) gem
- Threads spawn a new `Thread` per iteration for the responder
- Async is ~2.7x faster for inproc latency due to cheap fiber switching
- For throughput, threads are faster on inproc/ipc due to lower push/pull scheduling overhead

## Running

```sh
bundle exec ruby bench/async/throughput.rb
bundle exec ruby bench/async/latency.rb
bundle exec ruby bench/threads/throughput.rb
bundle exec ruby bench/threads/latency.rb
```
