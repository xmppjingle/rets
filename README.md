# rets

**Zero-latency, Redis-flavored caching for the BEAM — up to 30x faster than Redis.**

`rets` is a lightweight gen_server wrapper around ETS (Erlang Term Storage) that provides a familiar Redis-like API for in-memory key-value and hash operations. No network hop, no serialization overhead, no external dependencies — just raw BEAM speed with an API you already know.

## API

```erlang
%% Start the server
rets:start_link().

%% Create a named ETS table
rets:init_db(my_cache).

%% Key-value operations
rets:set(my_cache, Key, Value).
rets:get(my_cache, Key).          %% returns Value | undefined
rets:del(my_cache, Key).

%% Hash operations
rets:hset(my_cache, Key, Field, Value).  %% returns field count
rets:hget(my_cache, Key, Field).         %% returns Value | undefined
rets:hgetall(my_cache, Key).             %% returns map() | undefined
rets:hlen(my_cache, Key).               %% returns non_neg_integer()
rets:hdel(my_cache, Key, Field).         %% returns remaining field count
```

## Build & Test

Requires Erlang/OTP 25+ and rebar3.

```bash
# Local
make compile    # compile
make test       # unit tests (26 tests)
make perf       # performance benchmarks (6 benchmarks)
make check      # compile + xref + dialyzer + test + cover

# Dockerized (no Erlang required)
make docker-test   # compile + xref + eunit + cover
make docker-perf   # performance benchmarks
```

## Performance

Benchmarks measured with `timer:tc/1` via EUnit. Results from automated performance tests:

| Benchmark | Throughput |
|-----------|-----------|
| `set` sequential (100K ops) | ~2,200,000 ops/s |
| `get` sequential (100K ops) | ~3,300,000 ops/s |
| `hset` sequential (100K ops, 100 hashes) | ~60,000 ops/s |
| `hget` sequential (100K ops) | ~119,000 ops/s |
| Concurrent reads (10 procs x 10K) | ~5,200,000 ops/s |
| Concurrent writes (10 procs x 10K) | ~105,000 ops/s |
| Concurrent mixed R/W (10 procs x 10K) | ~128,000 ops/s |
| `hdel` churn (50K cycles) | ~1,550,000 ops/s |

Run `make perf` or `make docker-perf` to reproduce on your hardware.

### How does rets compare to Redis?

Because `rets` operates directly on ETS — in-process, with no network round-trip and no serialization — it dramatically outperforms Redis for local caching workloads:

| Operation | rets (ETS) | Redis (localhost) | Speedup |
|-----------|-----------|-------------------|---------|
| **GET** | ~3,300,000 ops/s | ~100–150K ops/s | **~25x faster** |
| **SET** | ~2,200,000 ops/s | ~100–150K ops/s | **~17x faster** |
| **Concurrent reads** | ~5,200,000 ops/s | ~200–400K ops/s (pipelined) | **~17x faster** |

> Redis benchmarks based on `redis-benchmark` on localhost with default settings. Actual results vary by hardware.

#### Why is rets faster?

- **No network overhead** — `ets:lookup/2` and `ets:insert/2` are direct memory operations; Redis requires a TCP round-trip even on localhost
- **No serialization** — Erlang terms stay native in ETS; Redis must encode/decode through the RESP protocol on every call
- **Lock-free concurrent reads** — ETS `public` tables allow parallel reads from any process without contention

#### When to use rets vs Redis

| | rets | Redis |
|---|---|---|
| **Best for** | Local in-process caching within a BEAM application | Shared state across services, persistence, pub/sub |
| Latency | Sub-microsecond | ~0.1–1 ms (localhost) |
| Persistence | None (in-memory only) | RDB snapshots, AOF |
| Distribution | Single BEAM node | Cluster, Sentinel |
| TTL / Expiry | Not built-in | Built-in |
| Data types | K/V + hash maps | Strings, lists, sets, sorted sets, streams, ... |
| Dependencies | None (ships with OTP) | External service |

**In short:** if your data lives and dies with your BEAM application and you need maximum throughput with zero operational overhead, `rets` is the right tool. If you need shared state across services, durability, or rich data structures, reach for Redis.

## CI

GitHub Actions runs on every push/PR against master:

- **Compile + xref + dialyzer + eunit + cover** across OTP 25, 26, 27
- **Performance benchmarks** on OTP 26
- **Docker build and test** validation

## License

Apache License 2.0
