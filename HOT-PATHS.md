# Measured hot paths

Produced by `.github/workflows/profile.yml`, which runs the real netns workload
under callgrind and publishes the tables to the `ci-profile` branch.

Callgrind is used rather than `perf` on purpose. Timing on this runner is
unusable: three runs of one unchanged commit differed by up to 75 percent, and
two runs of the same binary report `checksum/scalar/1500` as 70 percent slower
than itself. Instruction counts are deterministic and independent of the
machine, so a reduction in them is a real, reproducible result.

Run: `tcp-up-1`, 3 seconds, `zeptun-userspace`, MTU 8500, one queue, pool capped
to 64 buffers per worker so start-up does not swamp the packet path.
178 million instructions total.

## Self cost, top of the list

| function | self Ir | share |
|---|---:|---:|
| `stack.deliver` (`src/stack/tcp.zig`) | 21,072,536 | 11.80% |
| `parse.parse` | 12,741,290 | 7.13% |
| `Worker.iterate`, timer wheel inlined (`src/flow/timeouts.zig`) | 9,507,850 | 5.32% |
| `parse.parseTcpOptions` | 9,266,073 | 5.19% |
| `parse.parseIp` | 6,563,734 | 3.67% |
| `tcp.sendSegment` | 6,360,837 | 3.56% |
| `memcpy` | 6,316,659 | 3.54% |
| `memset` | 6,015,693 | 3.37% |
| `tcp.processAck` | 5,985,599 | 3.35% |
| `tcp.consumeRx` | 5,243,076 | 2.93% |
| `Worker.flushOutput` | 5,078,266 | 2.84% |
| `FlowKey` code inlined into `deliver` (`src/packet/parse.zig`) | 6,344,203 | 3.55% |
| `FlowKey.eql` and `hash` inlined into `Table.find` (`src/packet/parse.zig`) | 2,606,101 | 1.46% |
| `tcp.kickWrite` | 4,389,292 | 2.46% |
| `stack.dispatch` | 4,343,625 | 2.43% |
| `tcp.appendRx` | 4,039,844 | 2.26% |
| `linux.Queue.onRead` | 3,771,127 | 2.11% |
| `pool.Pool.take` | 3,104,864 | 1.74% |

## What the totals say

**`src/packet/parse.zig` is 21% of all user-space instructions.** Adding up every
line the profiler attributes to that file: `parse` 7.13, `parseTcpOptions` 5.19,
`parseIp` 3.67, plus 3.55 of `FlowKey` construction inlined into `deliver` and
1.46 of `FlowKey.eql`/`hash` inlined into `Table.find`.

The structural reason is that `Packet` is 60 bytes and `TcpOptions` is 48 bytes,
of which 32 is the SACK array. Both are built and returned by value on every
packet. `FlowKey` is 40 bytes, also built and returned by value on every packet,
and then compared 40 bytes at a time in the flow table.

`dispatch` parses each packet exactly once and passes the result down, so there
is no redundant parse to remove. The cost is materialisation, not repetition.

## Why there is no order of magnitude win here

The work is spread across inherent per-packet costs: header field extraction
(21%), stack state machine control flow (12%), data movement (7%), and the event
loop. No single item is doing redundant work that could be factored away. A
realistic bit-identical improvement to the parse path is on the order of 20 to
40 percent of 21 percent, which is 4 to 8 percent of the whole, and that is below
what the end-to-end benchmark can resolve.

## Two things this profile cannot see

**Kernel time.** Callgrind counts user-space instructions only. The syscall
wrappers (`epoll.submit`, `epoll.attempt`, `Loop.run`) are about 7% of user
instructions, but the cost of the syscalls themselves is invisible. For a TUN
tunnel this may be the actual bottleneck, and a user-space profile will never
show it.

**Per-iteration costs are distorted.** Valgrind runs roughly fifty times slower,
which makes the event loop return immediately instead of blocking. Anything paid
once per loop iteration is therefore over-represented. The 5.32% attributed to
the timer wheel is almost certainly inflated: `Wheel.advance` skips empty regions
using a two-level bitmap, and the cost is its call frequency, which valgrind
changes. Treat the timer wheel number as unreliable and the per-packet numbers as
reliable, because per-packet work scales with packets, not with loop iterations.

## Incidental finding

`buffers_per_worker` defaults to `clamp(256 MB / buffer_size, 256, 32768)`, which
at the default 70 KB buffer size is about 3800 buffers, or 268 MB allocated and
zeroed per worker before the first packet. On the Linux benchmark that is 81% of
all instructions recorded before the pool was capped. The mobile preset caps
`budget_bytes` at 24 MB, so phones are not affected, but the Linux default is
worth a second look.


## Update: the FlowKey zero-fill, and what it taught

`FlowKey.fromPacket` started from `.{ .proto = ..., .v6 = ... }`, whose defaults
are `@splat(0)` for both address arrays, so it cleared 32 bytes and then copied 4
of them into each half for IPv4. The callgrind site resolver, added in
`scripts/callgrind_sites.py`, put the profile's once-per-packet `memset` exactly
there: `parse.zig`, reached from `tcp.zig`.

Writing the bytes instead of clearing then filling removed it.

| per packet | before | after |
|---|---:|---:|
| `memset` calls | 1.001 | 0.001 |
| `memcpy` calls | 2.813 | 0.766 |
| `memset` Ir | 62.0 | 2.0 |
| `memcpy` Ir | 108.6 | 17.5 |
| **total self Ir** | **1729.6** | **1560.1** |

That is 9.8 percent fewer user-space instructions per packet, measured by
instruction count and therefore independent of the runner's two performance
states. The micro-benchmark agrees: `parse/ipv4-tcp+flowkey` 44.78 ns to 26.42 ns,
-41.0 percent, paired over five interleaved rounds, with the golden digest gate
reporting zero mismatches, so the forty bytes of every key are unchanged.

**The end-to-end netns benchmark shows nothing.** No scenario moved outside the
run-to-run variance, and one cell reported 39 percent spread, which is the
machine changing state mid-run rather than a result.

## The conclusion this forces

A 9.8 percent cut in user-space instructions and a 41 percent cut in the cost of
building a flow key produced no measurable throughput change. Together with the
earlier observation that callgrind cannot see kernel time, this says the
end-to-end throughput of this stack on this workload is **not limited by
user-space instruction count**.

That closes off the whole class of approach this file exists to enable. More
SIMD in the parse path, a cheaper hash, narrower structs, a faster state machine:
all of it reduces instructions, and instructions are demonstrably not the
constraint. The place to look instead is the side a user-space profile cannot
observe, namely the cost of the syscalls themselves, and the only reliable way to
attack that is to measure kernel time directly, with `perf` rather than
callgrind, or by counting and timing the syscalls per packet.
