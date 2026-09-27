# Failed experiment: micro-benchmark driven optimisation

Status: **failure**. Preserved on `experiments/failed-micro-opt` at `fafd5d0`.
Reverted on `bench/hardened` at `aac797e`. Nothing from the source changes ships.

## What was attempted

Two bit-identical optimisations, both measured with a paired in-job A/B against
`5620e57`, five interleaved rounds, minimum per side.

1. `sumScalar` in `src/packet/checksum.zig`: the loop fed every 64-bit word into a
   single accumulator through `addCarry`, which is two dependent operations, so a
   32-byte block cost a chain of eight dependent adds. Split into four
   accumulators folded once at the end, plus a 128-bit accumulator below 256
   bytes.
2. `Segmenter.next` in `src/packet/gso.zig`: re-summed all 20 IPv4 header bytes
   per segment, although only two 16-bit words change between consecutive
   segments. Replaced with one full sum plus two RFC 1624 updates per segment.

## What the micro-benchmark claimed

| target | base ns | new ns | delta |
|---|---:|---:|---:|
| `gso/split-64k-mss1460` | 1927 | 1334 | -30.8% |
| `checksum/scalar/65535` | 6699 | 3110 | -53.6% |
| `checksum/scalar/1500` | 149 | 75 | -49.3% |
| `checksum/scalar/512` | 45.9 | 27.6 | -39.9% |
| `checksum/scalar/64` | 5.16 | 5.56 | +7.8% |

## What the end-to-end benchmark showed

`benchmark.yml`, real netns run, SOCKS5 tunnel, MTU 8500, 4 s scenarios, control
being the same harness on unmodified sources:

| scenario | control | candidate | delta |
|---|---:|---:|---:|
| `zeptun-userspace tcp-up-1` | 19.09 | 18.68 | -2.2% |
| `zeptun-userspace tcp-up-10` | 22.40 | 21.48 | -4.1% |
| `zeptun-userspace rr` | 9735 tps | 7084 tps | -27.2% |
| `zeptun-hybrid rr` | 8672 tps | 6594 tps | -24.0% |

Nothing improved. Nothing is claimed as a regression either, for reasons below.

## Why it failed

**`sumScalar` is not executed on any platform this project builds.** It is only
reached when `checksum.default_impl` is `.scalar`, which requires
`std.simd.suggestVectorLength(u16)` to be null or below 8. That value is 8 on
x86_64 with SSE2 and 8 on aarch64, so both dispatch to `sumSimd`. The function
that was made twice as fast is a fallback for targets without a usable `u16`
vector. The `checksum/scalar/*` rows in the micro-benchmark measure a path
production never takes, so a large win there means nothing.

**The GSO change is real work removed, but it is arithmetically capped.** 45
twenty-byte header sums is roughly 1.4 us per 64 KB super packet. Pushing 64 KB
at 20 Gbit/s takes about 26 us. Even at perfect efficiency the change is under
five percent, and the benchmark cannot resolve five percent.

## The two mistakes, stated plainly

1. **Optimising a function before proving it runs.** The micro-benchmark happily
   benchmarked `sumScalar` for twenty minutes and reported a 2x win. One line of
   static analysis, `suggestVectorLength(u16) >= 8` on both targets, would have
   killed the idea before any work was done. The benchmark had no way to tell me,
   because a micro-benchmark measures whatever you point it at.
2. **Trusting a single-run comparison across jobs.** The runner settles into one
   of two performance states. Three runs of one unchanged commit differed by up to
   75 percent, and the slow runs agreed with each other. Fed to the repository's
   own regression gate, two runs of the *same binary* report
   `checksum/scalar/1500` as 70 percent slower than itself. Any A/B taken from two
   separate jobs on this runner measures the machine, not the code. The paired
   in-job runner added in `25cd6f6` fixed this for micro-benchmarks; the netns
   A/B above still has one run per side and is under-powered for anything under
   roughly twenty percent, which is why the -27 percent on `rr` is not treated as
   a real regression either.

## What was kept

The benchmark work, which paid for itself immediately. The new capability table
from the first end-to-end run on this branch:

```
| engine            | multiqueue | queues requested | queues actual | processes |
| zeptun-userspace  | yes        | 4                | 1             | 1         |
```

Zeptun requested four TUN queues and was granted one. The previous harness wrote
`"queues":4` into the results for every engine regardless, so the published
multi-queue comparison in `docs/bench/README.md` was a single-queue comparison
labelled as four, and sing-box and tun2socks were never given multiple queues at
all.

## Rule for next time

Do not optimise a function until it is shown to be on a measured hot path of the
real workload. Profile the running engine first. A micro-benchmark is a tool for
confirming a change to a path you already know is hot, never for choosing one.
