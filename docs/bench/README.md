# Benchmarks

Every number on this page comes from the `benchmark` workflow in this repository, run on a GitHub-hosted runner.

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

![throughput](throughput.svg)

## CPU

![cpu](cpu.svg)

## Request/response

![transactions](transactions.svg)

![latency](latency.svg)

## UDP

![udp](udp.svg)

## Memory

![memory](memory.svg)

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


## TUN queues: 1

| engine | scenario | median | rounds | spread | cpu % | max rss MB | rss after idle MB |
|---|---|---:|---:|---:|---:|---:|---:|
| hev | crr | 1738 tps p50=560us p99=640us p99.9=736us | 3 | 1.0% | 56 | 3.9 | 3.8 |
| hev | rr | 7092 tps p50=134us p99=174us p99.9=196us | 3 | 2.3% | 39 | 3.9 | 3.8 |
| hev | rr-8x1k | 27570 tps p50=272us p99=608us p99.9=840us | 3 | 3.1% | 89 | 4.4 | 3.8 |
| hev | tcp-down-1 | 6.645 | 3 | 2.6% | 98 | 4.0 | 3.8 |
| hev | tcp-down-10 | 6.634 | 3 | 1.1% | 99 | 4.7 | 3.8 |
| hev | tcp-up-1 | 6.004 | 3 | 4.9% | 94 | 4.0 | 3.8 |
| hev | tcp-up-10 | 6.021 | 3 | 2.9% | 98 | 5.1 | 3.8 |
| hev | udp-100k | 77812 echo pps (77.8% of 100000 sent) | 3 | 7.3% | 100 | 6.6 | 6.6 |
| hev | udp-gso-100k | 76067 echo pps (76.1% of 100000 sent) | 3 | 2.5% | 98 | 6.6 | 6.6 |
| singbox-gvisor | crr | 1138 tps p50=856us p99=1056us p99.9=2048us | 3 | 0.7% | 104 | 75.6 | 75.6 |
| singbox-gvisor | rr | 4312 tps p50=230us p99=312us p99.9=500us | 3 | 1.1% | 80 | 86.5 | 85.1 |
| singbox-gvisor | rr-8x1k | 17462 tps p50=440us p99=840us p99.9=1152us | 3 | 0.5% | 168 | 85.1 | 73.9 |
| singbox-gvisor | tcp-down-1 | 3.159 | 3 | 0.9% | 182 | 82.1 | 73.4 |
| singbox-gvisor | tcp-down-10 | 5.644 | 3 | 1.6% | 244 | 86.5 | 86.5 |
| singbox-gvisor | tcp-up-1 | 9.051 | 3 | 6.3% | 160 | 71.8 | 71.8 |
| singbox-gvisor | tcp-up-10 | 14.790 | 3 | 3.2% | 199 | 82.1 | 82.1 |
| singbox-gvisor | udp-100k | 0 echo pps (0.0% of 99991 sent) | 3 | 0.0% | 173 | 76.8 | 76.1 |
| singbox-gvisor | udp-gso-100k | 0 | 3 | 0.0% | 0 | 76.1 | 76.1 |
| singbox-system | crr | 1270 tps p50=768us p99=888us p99.9=1648us | 3 | 0.3% | 101 | 70.6 | 70.6 |
| singbox-system | rr | 5561 tps p50=176us p99=208us p99.9=284us | 3 | 1.7% | 61 | 62.5 | 62.5 |
| singbox-system | rr-8x1k | 21887 tps p50=348us p99=720us p99.9=1016us | 3 | 0.5% | 153 | 63.9 | 63.9 |
| singbox-system | tcp-down-1 | 5.305 | 3 | 1.4% | 152 | 62.5 | 62.5 |
| singbox-system | tcp-down-10 | 3.837 | 3 | 2.5% | 137 | 62.5 | 62.5 |
| singbox-system | tcp-up-1 | 5.800 | 3 | 4.5% | 154 | 61.5 | 61.3 |
| singbox-system | tcp-up-10 | 4.428 | 3 | 1.2% | 170 | 61.4 | 61.4 |
| singbox-system | udp-100k | 0 echo pps (0.0% of 99984 sent) | 3 | 0.0% | 88 | 70.8 | 70.5 |
| singbox-system | udp-gso-100k | 0 echo pps (0.0% of 99967 sent) | 3 | 0.0% | 77 | 70.5 | 70.4 |
| tun2socks | crr | 1174 tps p50=824us p99=1024us p99.9=1776us | 3 | 0.8% | 91 | 129.9 | 123.6 |
| tun2socks | rr | 4534 tps p50=220us p99=260us p99.9=368us | 3 | 0.4% | 72 | 105.1 | 105.1 |
| tun2socks | rr-8x1k | 18382 tps p50=416us p99=832us p99.9=1120us | 3 | 0.7% | 168 | 121.6 | 121.6 |
| tun2socks | tcp-down-1 | 2.593 | 3 | 1.4% | 170 | 42.5 | 38.8 |
| tun2socks | tcp-down-10 | 6.019 | 3 | 1.1% | 258 | 96.6 | 97.1 |
| tun2socks | tcp-up-1 | 5.074 | 3 | 0.2% | 174 | 23.2 | 21.5 |
| tun2socks | tcp-up-10 | 7.578 | 3 | 1.5% | 259 | 38.4 | 38.4 |
| tun2socks | udp-100k | 38758 echo pps (38.8% of 99984 sent) | 3 | 1.9% | 217 | 70.5 | 49.3 |
| tun2socks | udp-gso-100k | 41675 echo pps (41.7% of 99959 sent) | 3 | 1.1% | 232 | 51.2 | 50.2 |
| zeptun-hybrid | crr | 1744 tps p50=560us p99=648us p99.9=1000us | 3 | 4.9% | 54 | 13.8 | 13.7 |
| zeptun-hybrid | rr | 6493 tps p50=148us p99=188us p99.9=220us | 3 | 3.3% | 40 | 9.4 | 9.2 |
| zeptun-hybrid | rr-8x1k | 23443 tps p50=324us p99=640us p99.9=888us | 3 | 0.4% | 95 | 9.3 | 9.2 |
| zeptun-hybrid | tcp-down-1 | 13.709 | 3 | 32.9% | 99 | 10.9 | 9.3 |
| zeptun-hybrid | tcp-down-10 | 12.631 | 3 | 2.5% | 99 | 10.9 | 9.3 |
| zeptun-hybrid | tcp-up-1 | 16.859 | 3 | 9.1% | 97 | 10.8 | 9.2 |
| zeptun-hybrid | tcp-up-10 | 11.471 | 3 | 4.0% | 98 | 10.9 | 9.3 |
| zeptun-hybrid | udp-100k | 80626 echo pps (80.7% of 99967 sent) | 3 | 2.5% | 73 | 16.5 | 15.8 |
| zeptun-hybrid | udp-gso-100k | 79103 echo pps (79.1% of 99992 sent) | 3 | 3.2% | 54 | 16.7 | 15.8 |
| zeptun-userspace | crr | 1955 tps p50=496us p99=592us p99.9=816us | 3 | 1.2% | 42 | 6.2 | 6.1 |
| zeptun-userspace | rr | 7083 tps p50=134us p99=172us p99.9=360us | 3 | 2.9% | 36 | 5.5 | 5.4 |
| zeptun-userspace | rr-8x1k | 30434 tps p50=252us p99=480us p99.9=608us | 3 | 2.7% | 80 | 5.5 | 5.4 |
| zeptun-userspace | tcp-down-1 | 11.794 | 3 | 5.0% | 99 | 5.5 | 5.4 |
| zeptun-userspace | tcp-down-10 | 11.686 | 3 | 3.1% | 98 | 8.3 | 7.9 |
| zeptun-userspace | tcp-up-1 | 18.007 | 3 | 8.1% | 78 | 7.2 | 5.3 |
| zeptun-userspace | tcp-up-10 | 14.556 | 3 | 14.8% | 95 | 8.0 | 5.3 |
| zeptun-userspace | udp-100k | 76676 echo pps (76.7% of 99976 sent) | 3 | 6.0% | 73 | 7.1 | 6.1 |
| zeptun-userspace | udp-gso-100k | 79810 echo pps (79.8% of 99967 sent) | 3 | 6.7% | 56 | 7.0 | 6.0 |

## Throughput by engine (best tier each engine reached)

| engine | queues | scenario | median |
|---|---:|---|---:|
| hev | 1 | crr | 1738 tps p50=560us p99=640us p99.9=736us |
| hev | 1 | rr | 7092 tps p50=134us p99=174us p99.9=196us |
| hev | 1 | rr-8x1k | 27570 tps p50=272us p99=608us p99.9=840us |
| hev | 1 | tcp-down-1 | 6.645 |
| hev | 1 | tcp-down-10 | 6.634 |
| hev | 1 | tcp-up-1 | 6.004 |
| hev | 1 | tcp-up-10 | 6.021 |
| hev | 1 | udp-100k | 77812 echo pps (77.8% of 100000 sent) |
| hev | 1 | udp-gso-100k | 76067 echo pps (76.1% of 100000 sent) |
| singbox-gvisor | 1 | crr | 1138 tps p50=856us p99=1056us p99.9=2048us |
| singbox-gvisor | 1 | rr | 4312 tps p50=230us p99=312us p99.9=500us |
| singbox-gvisor | 1 | rr-8x1k | 17462 tps p50=440us p99=840us p99.9=1152us |
| singbox-gvisor | 1 | tcp-down-1 | 3.159 |
| singbox-gvisor | 1 | tcp-down-10 | 5.644 |
| singbox-gvisor | 1 | tcp-up-1 | 9.051 |
| singbox-gvisor | 1 | tcp-up-10 | 14.790 |
| singbox-gvisor | 1 | udp-100k | 0 echo pps (0.0% of 99991 sent) |
| singbox-gvisor | 1 | udp-gso-100k | 0 |
| singbox-system | 1 | crr | 1270 tps p50=768us p99=888us p99.9=1648us |
| singbox-system | 1 | rr | 5561 tps p50=176us p99=208us p99.9=284us |
| singbox-system | 1 | rr-8x1k | 21887 tps p50=348us p99=720us p99.9=1016us |
| singbox-system | 1 | tcp-down-1 | 5.305 |
| singbox-system | 1 | tcp-down-10 | 3.837 |
| singbox-system | 1 | tcp-up-1 | 5.800 |
| singbox-system | 1 | tcp-up-10 | 4.428 |
| singbox-system | 1 | udp-100k | 0 echo pps (0.0% of 99984 sent) |
| singbox-system | 1 | udp-gso-100k | 0 echo pps (0.0% of 99967 sent) |
| tun2socks | 1 | crr | 1174 tps p50=824us p99=1024us p99.9=1776us |
| tun2socks | 1 | rr | 4534 tps p50=220us p99=260us p99.9=368us |
| tun2socks | 1 | rr-8x1k | 18382 tps p50=416us p99=832us p99.9=1120us |
| tun2socks | 1 | tcp-down-1 | 2.593 |
| tun2socks | 1 | tcp-down-10 | 6.019 |
| tun2socks | 1 | tcp-up-1 | 5.074 |
| tun2socks | 1 | tcp-up-10 | 7.578 |
| tun2socks | 1 | udp-100k | 38758 echo pps (38.8% of 99984 sent) |
| tun2socks | 1 | udp-gso-100k | 41675 echo pps (41.7% of 99959 sent) |
| zeptun-hybrid | 1 | crr | 1744 tps p50=560us p99=648us p99.9=1000us |
| zeptun-hybrid | 1 | rr | 6493 tps p50=148us p99=188us p99.9=220us |
| zeptun-hybrid | 1 | rr-8x1k | 23443 tps p50=324us p99=640us p99.9=888us |
| zeptun-hybrid | 1 | tcp-down-1 | 13.709 |
| zeptun-hybrid | 1 | tcp-down-10 | 12.631 |
| zeptun-hybrid | 1 | tcp-up-1 | 16.859 |
| zeptun-hybrid | 1 | tcp-up-10 | 11.471 |
| zeptun-hybrid | 1 | udp-100k | 80626 echo pps (80.7% of 99967 sent) |
| zeptun-hybrid | 1 | udp-gso-100k | 79103 echo pps (79.1% of 99992 sent) |
| zeptun-userspace | 1 | crr | 1955 tps p50=496us p99=592us p99.9=816us |
| zeptun-userspace | 1 | rr | 7083 tps p50=134us p99=172us p99.9=360us |
| zeptun-userspace | 1 | rr-8x1k | 30434 tps p50=252us p99=480us p99.9=608us |
| zeptun-userspace | 1 | tcp-down-1 | 11.794 |
| zeptun-userspace | 1 | tcp-down-10 | 11.686 |
| zeptun-userspace | 1 | tcp-up-1 | 18.007 |
| zeptun-userspace | 1 | tcp-up-10 | 14.556 |
| zeptun-userspace | 1 | udp-100k | 76676 echo pps (76.7% of 99976 sent) |
| zeptun-userspace | 1 | udp-gso-100k | 79810 echo pps (79.8% of 99967 sent) |

| engine | multiqueue | queues requested | queues actual | processes |
|---|---|---:|---:|---:|
| hev | yes | 4 | 1 | 4 |
| zeptun-hybrid | yes | 4 | 1 | 1 |
| zeptun-userspace | yes | 4 | 1 | 1 |
# Benchmark results

Engines are grouped by the number of TUN queues they actually received, so a
single-queue engine is never compared against a multi-queue engine inside one table.

> hev was asked for 4 queues but got 1.

> zeptun-hybrid was asked for 4 queues but got 1.

> zeptun-userspace was asked for 4 queues but got 1.


## TUN queues: 1

| engine | scenario | median | rounds | spread | cpu % | max rss MB | rss after idle MB |
|---|---|---:|---:|---:|---:|---:|---:|
| hev | crr | 1723 tps p50=560us p99=648us p99.9=768us | 3 | 1.3% | 64 | 15.5 | 15.2 |
| hev | rr | 6952 tps p50=138us p99=180us p99.9=288us | 3 | 3.5% | 38 | 15.3 | 15.2 |
| hev | rr-8x1k | 31320 tps p50=246us p99=468us p99.9=624us | 3 | 14.7% | 127 | 15.8 | 15.2 |
| hev | tcp-down-1 | 6.469 | 3 | 6.8% | 98 | 15.4 | 15.2 |
| hev | tcp-down-10 | 10.966 | 3 | 1.3% | 207 | 16.1 | 15.2 |
| hev | tcp-up-1 | 5.763 | 3 | 5.8% | 94 | 15.0 | 14.8 |
| hev | tcp-up-10 | 12.871 | 3 | 5.6% | 217 | 16.2 | 15.2 |
| hev | udp-100k | 73700 echo pps (73.7% of 99984 sent) | 3 | 2.0% | 99 | 18.0 | 18.0 |
| hev | udp-gso-100k | 73138 echo pps (73.2% of 99975 sent) | 3 | 1.5% | 99 | 20.7 | 20.7 |
| zeptun-hybrid | crr | 1526 tps p50=640us p99=752us p99.9=888us | 3 | 2.2% | 68 | 27.6 | 27.8 |
| zeptun-hybrid | rr | 6365 tps p50=154us p99=188us p99.9=206us | 3 | 7.1% | 40 | 22.6 | 22.5 |
| zeptun-hybrid | rr-8x1k | 28789 tps p50=264us p99=512us p99.9=664us | 3 | 3.2% | 139 | 26.1 | 26.0 |
| zeptun-hybrid | tcp-down-1 | 12.383 | 3 | 2.9% | 99 | 19.0 | 18.4 |
| zeptun-hybrid | tcp-down-10 | 21.300 | 3 | 10.8% | 196 | 23.1 | 22.4 |
| zeptun-hybrid | tcp-up-1 | 11.405 | 3 | 8.1% | 99 | 15.0 | 14.2 |
| zeptun-hybrid | tcp-up-10 | 19.444 | 3 | 6.1% | 173 | 17.5 | 18.8 |
| zeptun-hybrid | udp-100k | 81416 echo pps (81.4% of 99967 sent) | 3 | 10.6% | 100 | 30.2 | 29.8 |
| zeptun-hybrid | udp-gso-100k | 76578 echo pps (76.6% of 99984 sent) | 3 | 2.7% | 53 | 34.4 | 33.8 |
| zeptun-userspace | crr | 1902 tps p50=508us p99=592us p99.9=760us | 3 | 1.9% | 46 | 18.3 | 18.3 |
| zeptun-userspace | rr | 7065 tps p50=134us p99=174us p99.9=204us | 3 | 5.2% | 36 | 14.6 | 14.6 |
| zeptun-userspace | rr-8x1k | 31592 tps p50=242us p99=476us p99.9=608us | 3 | 4.2% | 100 | 14.7 | 14.6 |
| zeptun-userspace | tcp-down-1 | 11.160 | 3 | 10.0% | 99 | 12.1 | 12.0 |
| zeptun-userspace | tcp-down-10 | 19.308 | 3 | 2.5% | 172 | 18.0 | 15.3 |
| zeptun-userspace | tcp-up-1 | 18.494 | 3 | 7.1% | 83 | 14.9 | 11.8 |
| zeptun-userspace | tcp-up-10 | 20.191 | 3 | 3.8% | 128 | 17.2 | 11.9 |
| zeptun-userspace | udp-100k | 79662 echo pps (79.7% of 99984 sent) | 3 | 1.7% | 75 | 21.1 | 20.2 |
| zeptun-userspace | udp-gso-100k | 80962 echo pps (81.0% of 99976 sent) | 3 | 6.1% | 57 | 21.1 | 20.0 |

## Throughput by engine (best tier each engine reached)

| engine | queues | scenario | median |
|---|---:|---|---:|
| hev | 1 | crr | 1723 tps p50=560us p99=648us p99.9=768us |
| hev | 1 | rr | 6952 tps p50=138us p99=180us p99.9=288us |
| hev | 1 | rr-8x1k | 31320 tps p50=246us p99=468us p99.9=624us |
| hev | 1 | tcp-down-1 | 6.469 |
| hev | 1 | tcp-down-10 | 10.966 |
| hev | 1 | tcp-up-1 | 5.763 |
| hev | 1 | tcp-up-10 | 12.871 |
| hev | 1 | udp-100k | 73700 echo pps (73.7% of 99984 sent) |
| hev | 1 | udp-gso-100k | 73138 echo pps (73.2% of 99975 sent) |
| zeptun-hybrid | 1 | crr | 1526 tps p50=640us p99=752us p99.9=888us |
| zeptun-hybrid | 1 | rr | 6365 tps p50=154us p99=188us p99.9=206us |
| zeptun-hybrid | 1 | rr-8x1k | 28789 tps p50=264us p99=512us p99.9=664us |
| zeptun-hybrid | 1 | tcp-down-1 | 12.383 |
| zeptun-hybrid | 1 | tcp-down-10 | 21.300 |
| zeptun-hybrid | 1 | tcp-up-1 | 11.405 |
| zeptun-hybrid | 1 | tcp-up-10 | 19.444 |
| zeptun-hybrid | 1 | udp-100k | 81416 echo pps (81.4% of 99967 sent) |
| zeptun-hybrid | 1 | udp-gso-100k | 76578 echo pps (76.6% of 99984 sent) |
| zeptun-userspace | 1 | crr | 1902 tps p50=508us p99=592us p99.9=760us |
| zeptun-userspace | 1 | rr | 7065 tps p50=134us p99=174us p99.9=204us |
| zeptun-userspace | 1 | rr-8x1k | 31592 tps p50=242us p99=476us p99.9=608us |
| zeptun-userspace | 1 | tcp-down-1 | 11.160 |
| zeptun-userspace | 1 | tcp-down-10 | 19.308 |
| zeptun-userspace | 1 | tcp-up-1 | 18.494 |
| zeptun-userspace | 1 | tcp-up-10 | 20.191 |
| zeptun-userspace | 1 | udp-100k | 79662 echo pps (79.7% of 99984 sent) |
| zeptun-userspace | 1 | udp-gso-100k | 80962 echo pps (81.0% of 99976 sent) |

zeptun: startup 4 ms, idle 836 KB, 5 wakeups in 20 s | tcp 1000: 7832 KB (conns: 1000/1000 established, 0 failed, 1751 conn/s) | udp 1000: 6172 KB (udp flows: 1000/1000 answered, 8485 flows/s)
hev: startup 3 ms, idle 2221 KB, 2 wakeups in 20 s | tcp 1000: 78794 KB (conns: 1000/1000 established, 0 failed, 1915 conn/s) | udp 1000: 27338 KB (udp flows: 1000/1000 answered, 7122 flows/s)
singbox-system: startup 49 ms, idle 58329 KB, 6 wakeups in 20 s | tcp 1000: 73960 KB (conns: 1000/1000 established, 0 failed, 1334 conn/s) | udp 1000: 71452 KB (udp flows: 0/1000 answered, 0 flows/s)
singbox-gvisor: startup 51 ms, idle 61025 KB, 124 wakeups in 20 s | tcp 1000: 96852 KB (conns: 1000/1000 established, 0 failed, 1239 conn/s) | udp 1000: 102884 KB (udp flows: 0/1000 answered, 0 flows/s)
tun2socks: startup 5 ms, idle 15836 KB, 257 wakeups in 20 s | tcp 1000: 109328 KB (conns: 1000/1000 established, 0 failed, 1194 conn/s) | udp 1000: 185788 KB (udp flows: 1000/1000 answered, 5729 flows/s)
