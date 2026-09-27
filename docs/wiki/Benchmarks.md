# Benchmarks

Every number here is produced by the `benchmark` workflow in the repository, on a GitHub-hosted runner, against hev-socks5-tunnel, sing-box and tun2socks over the same SOCKS5 server.

## Machine

| property | value |
|---|---|
| runner image | ubuntu24 20260920.314.1 |
| cpu | AMD EPYC 7763 64-Core Processor |
| cpu cores | 4 |
| memory | 15.6 GB |
| kernel | Linux 6.17.0-1022-azure |
| zig | 0.16.0 |
| date | 2026-09-27 |

## Method

Two network namespaces joined by a veth pair. Traffic enters the tunnel device (MTU 8500), leaves through the same SOCKS5 server (hev-socks5-server) for every engine, and reaches the servers in the second namespace. CPU comes from `/proc/<pid>/stat` and memory from `VmRSS`, summed over all processes of an engine.

Results are produced in two tiers and never mixed in one table. The fair tier runs every engine on a single TUN queue. The multi queue tier runs only the engines that can attach more than one queue. The queue count actually granted by the kernel is read back from `/sys/class/net/<dev>/queues` and printed in the capability table, so an engine that silently got fewer queues than requested is visible instead of being compared as if it had them.

Each engine is started once per round, warmed up with a discarded transfer, and then measured on every scenario. The order of engines is rotated each round so a systematic position in the round cannot favour the first engine. Duration 4 s per scenario, 3 rounds. Memory is read twice: the highest sample while the scenario runs, and again after 2 s of idle, which shows whether an engine gives the memory back.

## Throughput

![throughput](res/throughput.svg)

## CPU

![cpu](res/cpu.svg)

## Request and response

![transactions](res/transactions.svg)

![latency](res/latency.svg)

## UDP

![udp](res/udp.svg)

## Memory

Memory is read twice per scenario: the highest sample while the load runs, and
again after a few seconds of idle. The second reading is what shows whether an
engine hands the memory back or keeps it for the life of the process.

![memory](res/memory.svg)

## Scenarios

| Scenario | What it measures |
|---|---|
| `tcp-up-1`, `tcp-up-10` | bulk upload over one and ten streams |
| `tcp-down-1`, `tcp-down-10` | the same downstream |
| `rr` | request and response on a held connection, one at a time |
| `rr-8x1k` | eight connections exchanging 1 KB messages |
| `crr` | connect, exchange, close, repeatedly |
| `udp-100k` | 100k datagrams per second, echoed |
| `udp-gso-100k` | the same with segmentation offload on the client |

## Raw results

| engine | multiqueue | queues requested | queues actual | processes |
|---|---|---:|---:|---:|
| hev | yes | 1 | 1 | 1 |
| singbox-gvisor | no | 1 | 1 | 1 |
| singbox-system | no | 1 | 1 | 1 |
| tun2socks | no | 1 | 1 | 1 |
| zeptun-hybrid | yes | 1 | 1 | 1 |
| zeptun-userspace | yes | 1 | 1 | 1 |
# Benchmark results

Engines are grouped by the number of TUN queues they actually received, so a
single-queue engine is never compared against a multi-queue engine inside one table.

## Reproducing

```sh
gh workflow run benchmark.yml --repo Noisemux/zeptun -f duration=8 -f repeat=2
```
