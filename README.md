# rets

Redis-flavored Erlang ETS cache interface.

`rets` is a lightweight gen_server wrapper around ETS (Erlang Term Storage) that provides a Redis-like API for in-memory key-value and hash operations.

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

Benchmarks measured on EUnit with `timer:tc/1`. Results from automated performance tests:

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

## CI

GitHub Actions runs on every push/PR against master:

- **Compile + xref + dialyzer + eunit + cover** across OTP 25, 26, 27
- **Performance benchmarks** on OTP 26
- **Docker build and test** validation

## License

Apache License 2.0
