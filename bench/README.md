# Benchmark Results

NNG 1.10.0 | Ruby 4.0.1 | Linux x86_64 | Intel i7-9750H @ 2.60GHz

## Throughput (push/pull, iterations/s)

### Async (fibers)

| Size | inproc | ipc | tcp |
|------|--------|-----|-----|
| 64B | 29.3k | 11.3k | 7.9k |
| 256B | 29.5k | 10.5k | 7.3k |
| 1024B | 24.9k | 9.9k | 7.6k |
| 4096B | 22.9k | 7.8k | 7.1k |

### Threads

| Size | inproc | ipc | tcp |
|------|--------|-----|-----|
| 64B | 32.2k | 15.6k | 7.8k |
| 256B | 31.0k | 15.6k | 9.9k |
| 1024B | 29.3k | 15.9k | 9.1k |
| 4096B | 29.5k | 9.9k | 9.3k |

## Latency (req/rep roundtrip)

### Async (fibers)

| Transport | roundtrips/s | latency |
|-----------|-------------|---------|
| inproc | 9.2k | 109 us |
| ipc | 4.7k | 211 us |
| tcp | 4.5k | 223 us |

### Threads

| Transport | roundtrips/s | latency |
|-----------|-------------|---------|
| inproc | 4.5k | 221 us |
| ipc | 3.9k | 258 us |
| tcp | 3.5k | 282 us |

## Notes

- Throughput measures one-way push/pull (no reply needed)
- Latency measures full req/rep roundtrip
- Async uses Ruby fibers via the [async](https://github.com/socketry/async) gem
- Threads spawn a new `Thread` per iteration for the responder
- Async is ~2x faster for inproc latency due to cheap fiber switching
- For throughput, threads are slightly faster on inproc/ipc because push/pull has no responder overhead — the thread scheduler handles the kernel I/O well

## Running

```sh
bundle exec ruby bench/async/throughput.rb
bundle exec ruby bench/async/latency.rb
bundle exec ruby bench/threads/throughput.rb
bundle exec ruby bench/threads/latency.rb
```
