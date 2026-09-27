# Failed experiment: SOCKS5 warm pool size and the request/response deficit

Status: **failure**. Recorded on `perf/hotpaths`. No source change resulted.

## The claim under test

`rr` is the benchmark being lost. On the fair single-queue tier, measured in
the same run:

| engine | rr |
|---|---:|
| hev | 7401 tps |
| zeptun-userspace | 6982 tps |

`rr` runs with `--conns 1`, so it is latency-bound rather than
throughput-bound: each cycle is connect, request, response, close, and p50 is
about 136 us. Whatever costs time is per-connection serial latency, not
per-packet work.

The SOCKS5 warm pool defaults to four pre-connected sockets against a capacity
of sixteen (`pool_size: u16 = 4`, `warm_capacity = 16`), and every proxied
connection needs one. If the pool were running dry, each miss would cost a
further round trip to the proxy.

## What the first run showed

Changing nothing but `--socks5-pool 4` to `--socks5-pool 16`, same source, same
runner class:

| scenario | pool=4 | pool=16 | delta |
|---|---:|---:|---:|
| zeptun-userspace rr | 6982 | 7561 | **+8.3%** |
| zeptun-userspace rr-8x1k | 31453 | 33044 | +5.1% |

At 7561 the engine also passed hev's 7401, which made the story look complete.

## Why it was wrong

Two runs per side, best of each:

| scenario | pool=4 | pool=16 | delta |
|---|---|---|---:|
| zeptun-userspace rr | 6982, 7013 | 7561, 7065 | +1.2% |
| zeptun-userspace rr-8x1k | 31453, 29539 | 33044, 31592 | +7.0% |
| zeptun-userspace crr | 1928, 1978 | 1944, 1902 | -1.3% |
| zeptun-hybrid rr | 6411, 6500 | 6539, 6365 | -0.7% |

The second pool=16 run came in at 7065, indistinguishable from pool=4. The
apparent 8.3 percent was the runner's two performance states, not the pool. The
pool is not the constraint.

## The pattern this completes

This is the third time an encouraging result has evaporated under repetition:

| attempt | isolated result | end to end |
|---|---|---|
| scalar checksum accumulators | -49 percent, and -9.8 percent of all instructions per packet | wash |
| GSO IPv4 header checksum | -30.8 percent on the isolated operation | wash |
| SOCKS5 warm pool 4 to 16 | +8.3 percent rr on the first run | +1.2 percent on the best of two |

Each time the isolated measurement was real. Each time the end-to-end result
was not. The instruction profile explains why for the first two: user-space
instruction count is not what limits throughput here, and callgrind cannot see
kernel time at all. For this one the mechanism is the runner.

## What is actually left

The only remaining explanation for the `rr` deficit that is not a micro
optimisation is that it is structural: the client handshake and the upstream
SOCKS5 connect are performed in series, so a new connection pays for both. The
fix would be to begin the upstream connect when the SYN arrives rather than
after the client side is established, overlapping two round trips into one.
That is an architectural change to the connection setup path, not a rewrite of
a hot function, and it is not something the current benchmark can validate
because the effect would be about round-trip count rather than any per-packet
cost.

Measuring it first would need round-trip instrumentation, not an instruction
count. The profile already shows where the user-space time goes for `rr`, and
the answer is that 19.4 percent is event loop and syscall submission, with 2.5
buffer acquisitions per packet against 1.25 in bulk transfer.
