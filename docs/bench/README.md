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

Each engine is started once per round, warmed up with a discarded transfer, and then measured on every scenario. The order of engines is rotated each round so a systematic position in the round cannot favour the first engine. Duration 4 s per scenario, 2 rounds. Memory is read twice: the highest sample while the scenario runs, and again after 2 s of idle, which shows whether an engine gives the memory back.

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

> Only 2 round(s) per cell; treat differences under ~10% as noise.


## TUN queues: 1

| engine | scenario | median | rounds | spread | cpu % | max rss MB | rss after idle MB |
|---|---|---:|---:|---:|---:|---:|---:|
| hev | crr | 1773 tps p50=552us p99=616us p99.9=784us | 2 | 0.0% | 56 | 3.9 | 3.8 |
| hev | rr | 7014 tps p50=138us p99=174us p99.9=212us | 2 | 0.8% | 39 | 3.9 | 3.8 |
| hev | rr-8x1k | 28162 tps p50=260us p99=632us p99.9=944us | 2 | 2.3% | 89 | 4.4 | 3.8 |
| hev | tcp-down-1 | 6.879 | 2 | 5.2% | 98 | 4.0 | 3.8 |
| hev | tcp-down-10 | 6.619 | 2 | 1.0% | 99 | 4.7 | 3.8 |
| hev | tcp-up-1 | 6.050 | 2 | 4.8% | 96 | 4.0 | 3.8 |
| hev | tcp-up-10 | 6.125 | 2 | 3.2% | 98 | 5.1 | 3.8 |
| hev | udp-100k | 75296 echo pps (75.3% of 99984 sent) | 2 | 3.4% | 98 | 6.6 | 6.6 |
| hev | udp-gso-100k | 75950 echo pps (76.0% of 100000 sent) | 2 | 1.2% | 100 | 6.6 | 7.3 |
| singbox-gvisor | crr | 1156 tps p50=848us p99=1024us p99.9=1824us | 2 | 0.5% | 104 | 75.8 | 75.8 |
| singbox-gvisor | rr | 4424 tps p50=226us p99=276us p99.9=344us | 2 | 0.7% | 81 | 86.7 | 86.7 |
| singbox-gvisor | rr-8x1k | 17554 tps p50=436us p99=832us p99.9=1120us | 2 | 1.3% | 168 | 86.7 | 74.8 |
| singbox-gvisor | tcp-down-1 | 3.223 | 2 | 0.5% | 182 | 82.5 | 73.1 |
| singbox-gvisor | tcp-down-10 | 5.686 | 2 | 0.1% | 244 | 86.7 | 86.7 |
| singbox-gvisor | tcp-up-1 | 9.171 | 2 | 5.2% | 155 | 72.0 | 71.6 |
| singbox-gvisor | tcp-up-10 | 15.173 | 2 | 1.7% | 194 | 82.3 | 82.3 |
| singbox-gvisor | udp-100k | 0 echo pps (0.0% of 99976 sent) | 2 | 0.0% | 173 | 76.7 | 76.3 |
| singbox-gvisor | udp-gso-100k | 0 | 2 | 0.0% | 0 | 76.3 | 76.3 |
| singbox-system | crr | 1288 tps p50=760us p99=872us p99.9=1488us | 2 | 0.4% | 101 | 68.5 | 68.5 |
| singbox-system | rr | 5650 tps p50=172us p99=204us p99.9=220us | 2 | 1.2% | 62 | 61.5 | 61.5 |
| singbox-system | rr-8x1k | 21901 tps p50=348us p99=704us p99.9=960us | 2 | 0.3% | 154 | 61.5 | 61.1 |
| singbox-system | tcp-down-1 | 5.303 | 2 | 1.3% | 150 | 61.5 | 61.5 |
| singbox-system | tcp-down-10 | 3.954 | 2 | 1.1% | 137 | 61.5 | 61.5 |
| singbox-system | tcp-up-1 | 5.879 | 2 | 0.9% | 164 | 61.7 | 61.6 |
| singbox-system | tcp-up-10 | 4.668 | 2 | 1.6% | 171 | 61.7 | 61.7 |
| singbox-system | udp-100k | 0 echo pps (0.0% of 99967 sent) | 2 | 0.0% | 88 | 70.6 | 70.4 |
| singbox-system | udp-gso-100k | 0 echo pps (0.0% of 99967 sent) | 2 | 0.0% | 76 | 70.9 | 70.4 |
| tun2socks | crr | 1201 tps p50=808us p99=984us p99.9=1984us | 2 | 0.6% | 91 | 126.0 | 126.0 |
| tun2socks | rr | 4641 tps p50=214us p99=246us p99.9=280us | 2 | 0.5% | 73 | 105.2 | 105.2 |
| tun2socks | rr-8x1k | 18471 tps p50=412us p99=832us p99.9=1088us | 2 | 0.3% | 168 | 119.9 | 119.9 |
| tun2socks | tcp-down-1 | 2.687 | 2 | 3.7% | 170 | 39.6 | 34.0 |
| tun2socks | tcp-down-10 | 6.252 | 2 | 1.3% | 256 | 105.2 | 105.2 |
| tun2socks | tcp-up-1 | 5.039 | 2 | 0.7% | 172 | 22.2 | 20.7 |
| tun2socks | tcp-up-10 | 7.924 | 2 | 5.5% | 251 | 38.3 | 38.3 |
| tun2socks | udp-100k | 39641 echo pps (39.7% of 99968 sent) | 2 | 0.0% | 213 | 41.8 | 54.2 |
| tun2socks | udp-gso-100k | 42541 echo pps (42.6% of 99950 sent) | 2 | 1.3% | 230 | 53.6 | 51.4 |
| zeptun-hybrid | crr | 1772 tps p50=552us p99=616us p99.9=696us | 2 | 0.1% | 55 | 12.5 | 12.5 |
| zeptun-hybrid | rr | 6499 tps p50=150us p99=186us p99.9=210us | 2 | 1.6% | 40 | 9.2 | 9.1 |
| zeptun-hybrid | rr-8x1k | 23838 tps p50=316us p99=704us p99.9=1120us | 2 | 3.0% | 95 | 9.2 | 9.0 |
| zeptun-hybrid | tcp-down-1 | 14.317 | 2 | 0.2% | 99 | 10.8 | 9.2 |
| zeptun-hybrid | tcp-down-10 | 13.910 | 2 | 1.7% | 98 | 10.8 | 9.2 |
| zeptun-hybrid | tcp-up-1 | 16.415 | 2 | 2.1% | 98 | 10.8 | 9.2 |
| zeptun-hybrid | tcp-up-10 | 11.712 | 2 | 0.3% | 98 | 10.8 | 9.2 |
| zeptun-hybrid | udp-100k | 76504 echo pps (76.5% of 99984 sent) | 2 | 5.4% | 72 | 15.5 | 14.6 |
| zeptun-hybrid | udp-gso-100k | 83604 echo pps (83.6% of 99984 sent) | 2 | 8.3% | 55 | 15.5 | 14.6 |
| zeptun-userspace | crr | 2014 tps p50=480us p99=536us p99.9=632us | 2 | 0.1% | 42 | 10.3 | 10.3 |
| zeptun-userspace | rr | 7252 tps p50=134us p99=170us p99.9=188us | 2 | 3.8% | 36 | 7.4 | 7.4 |
| zeptun-userspace | rr-8x1k | 30446 tps p50=252us p99=472us p99.9=608us | 2 | 3.7% | 79 | 7.5 | 7.4 |
| zeptun-userspace | tcp-down-1 | 12.300 | 2 | 1.3% | 99 | 7.5 | 7.4 |
| zeptun-userspace | tcp-down-10 | 11.787 | 2 | 0.2% | 99 | 10.1 | 7.4 |
| zeptun-userspace | tcp-up-1 | 18.826 | 2 | 6.2% | 84 | 6.8 | 5.2 |
| zeptun-userspace | tcp-up-10 | 14.729 | 2 | 10.0% | 96 | 10.2 | 7.3 |
| zeptun-userspace | udp-100k | 79989 echo pps (80.0% of 100000 sent) | 2 | 9.6% | 73 | 11.1 | 10.3 |
| zeptun-userspace | udp-gso-100k | 76863 echo pps (76.9% of 99984 sent) | 2 | 3.6% | 52 | 11.2 | 10.2 |

## Throughput by engine (best tier each engine reached)

| engine | queues | scenario | median |
|---|---:|---|---:|
| hev | 1 | crr | 1773 tps p50=552us p99=616us p99.9=784us |
| hev | 1 | rr | 7014 tps p50=138us p99=174us p99.9=212us |
| hev | 1 | rr-8x1k | 28162 tps p50=260us p99=632us p99.9=944us |
| hev | 1 | tcp-down-1 | 6.879 |
| hev | 1 | tcp-down-10 | 6.619 |
| hev | 1 | tcp-up-1 | 6.050 |
| hev | 1 | tcp-up-10 | 6.125 |
| hev | 1 | udp-100k | 75296 echo pps (75.3% of 99984 sent) |
| hev | 1 | udp-gso-100k | 75950 echo pps (76.0% of 100000 sent) |
| singbox-gvisor | 1 | crr | 1156 tps p50=848us p99=1024us p99.9=1824us |
| singbox-gvisor | 1 | rr | 4424 tps p50=226us p99=276us p99.9=344us |
| singbox-gvisor | 1 | rr-8x1k | 17554 tps p50=436us p99=832us p99.9=1120us |
| singbox-gvisor | 1 | tcp-down-1 | 3.223 |
| singbox-gvisor | 1 | tcp-down-10 | 5.686 |
| singbox-gvisor | 1 | tcp-up-1 | 9.171 |
| singbox-gvisor | 1 | tcp-up-10 | 15.173 |
| singbox-gvisor | 1 | udp-100k | 0 echo pps (0.0% of 99976 sent) |
| singbox-gvisor | 1 | udp-gso-100k | 0 |
| singbox-system | 1 | crr | 1288 tps p50=760us p99=872us p99.9=1488us |
| singbox-system | 1 | rr | 5650 tps p50=172us p99=204us p99.9=220us |
| singbox-system | 1 | rr-8x1k | 21901 tps p50=348us p99=704us p99.9=960us |
| singbox-system | 1 | tcp-down-1 | 5.303 |
| singbox-system | 1 | tcp-down-10 | 3.954 |
| singbox-system | 1 | tcp-up-1 | 5.879 |
| singbox-system | 1 | tcp-up-10 | 4.668 |
| singbox-system | 1 | udp-100k | 0 echo pps (0.0% of 99967 sent) |
| singbox-system | 1 | udp-gso-100k | 0 echo pps (0.0% of 99967 sent) |
| tun2socks | 1 | crr | 1201 tps p50=808us p99=984us p99.9=1984us |
| tun2socks | 1 | rr | 4641 tps p50=214us p99=246us p99.9=280us |
| tun2socks | 1 | rr-8x1k | 18471 tps p50=412us p99=832us p99.9=1088us |
| tun2socks | 1 | tcp-down-1 | 2.687 |
| tun2socks | 1 | tcp-down-10 | 6.252 |
| tun2socks | 1 | tcp-up-1 | 5.039 |
| tun2socks | 1 | tcp-up-10 | 7.924 |
| tun2socks | 1 | udp-100k | 39641 echo pps (39.7% of 99968 sent) |
| tun2socks | 1 | udp-gso-100k | 42541 echo pps (42.6% of 99950 sent) |
| zeptun-hybrid | 1 | crr | 1772 tps p50=552us p99=616us p99.9=696us |
| zeptun-hybrid | 1 | rr | 6499 tps p50=150us p99=186us p99.9=210us |
| zeptun-hybrid | 1 | rr-8x1k | 23838 tps p50=316us p99=704us p99.9=1120us |
| zeptun-hybrid | 1 | tcp-down-1 | 14.317 |
| zeptun-hybrid | 1 | tcp-down-10 | 13.910 |
| zeptun-hybrid | 1 | tcp-up-1 | 16.415 |
| zeptun-hybrid | 1 | tcp-up-10 | 11.712 |
| zeptun-hybrid | 1 | udp-100k | 76504 echo pps (76.5% of 99984 sent) |
| zeptun-hybrid | 1 | udp-gso-100k | 83604 echo pps (83.6% of 99984 sent) |
| zeptun-userspace | 1 | crr | 2014 tps p50=480us p99=536us p99.9=632us |
| zeptun-userspace | 1 | rr | 7252 tps p50=134us p99=170us p99.9=188us |
| zeptun-userspace | 1 | rr-8x1k | 30446 tps p50=252us p99=472us p99.9=608us |
| zeptun-userspace | 1 | tcp-down-1 | 12.300 |
| zeptun-userspace | 1 | tcp-down-10 | 11.787 |
| zeptun-userspace | 1 | tcp-up-1 | 18.826 |
| zeptun-userspace | 1 | tcp-up-10 | 14.729 |
| zeptun-userspace | 1 | udp-100k | 79989 echo pps (80.0% of 100000 sent) |
| zeptun-userspace | 1 | udp-gso-100k | 76863 echo pps (76.9% of 99984 sent) |

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

> Only 2 round(s) per cell; treat differences under ~10% as noise.


## TUN queues: 1

| engine | scenario | median | rounds | spread | cpu % | max rss MB | rss after idle MB |
|---|---|---:|---:|---:|---:|---:|---:|
| hev | crr | 1761 tps p50=552us p99=624us p99.9=664us | 2 | 0.2% | 65 | 15.5 | 15.2 |
| hev | rr | 7219 tps p50=138us p99=170us p99.9=184us | 2 | 5.0% | 39 | 15.3 | 15.2 |
| hev | rr-8x1k | 31661 tps p50=228us p99=584us p99.9=736us | 2 | 0.5% | 125 | 15.8 | 15.2 |
| hev | tcp-down-1 | 6.484 | 2 | 2.0% | 99 | 15.4 | 15.2 |
| hev | tcp-down-10 | 11.053 | 2 | 2.2% | 206 | 16.0 | 15.2 |
| hev | tcp-up-1 | 5.994 | 2 | 0.8% | 96 | 15.0 | 14.9 |
| hev | tcp-up-10 | 13.377 | 2 | 8.1% | 216 | 16.3 | 15.4 |
| hev | udp-100k | 75683 echo pps (75.7% of 99975 sent) | 2 | 1.1% | 99 | 17.9 | 17.9 |
| hev | udp-gso-100k | 74907 echo pps (74.9% of 99984 sent) | 2 | 0.5% | 99 | 18.0 | 18.0 |
| zeptun-hybrid | crr | 1562 tps p50=624us p99=728us p99.9=832us | 2 | 0.4% | 68 | 16.5 | 16.2 |
| zeptun-hybrid | rr | 6594 tps p50=146us p99=184us p99.9=200us | 2 | 0.8% | 40 | 12.6 | 12.4 |
| zeptun-hybrid | rr-8x1k | 30213 tps p50=252us p99=568us p99.9=912us | 2 | 8.4% | 142 | 12.4 | 12.2 |
| zeptun-hybrid | tcp-down-1 | 12.773 | 2 | 0.4% | 99 | 11.1 | 10.5 |
| zeptun-hybrid | tcp-down-10 | 23.181 | 2 | 6.5% | 194 | 13.3 | 12.6 |
| zeptun-hybrid | tcp-up-1 | 11.844 | 2 | 11.8% | 99 | 8.5 | 8.0 |
| zeptun-hybrid | tcp-up-10 | 19.655 | 2 | 2.9% | 178 | 11.5 | 10.8 |
| zeptun-hybrid | udp-100k | 79905 echo pps (79.9% of 100000 sent) | 2 | 2.9% | 95 | 19.4 | 20.0 |
| zeptun-hybrid | udp-gso-100k | 81079 echo pps (81.1% of 99975 sent) | 2 | 5.0% | 55 | 22.5 | 22.0 |
| zeptun-userspace | crr | 2006 tps p50=484us p99=536us p99.9=656us | 2 | 3.6% | 44 | 16.9 | 16.8 |
| zeptun-userspace | rr | 7084 tps p50=136us p99=172us p99.9=188us | 2 | 0.5% | 36 | 14.5 | 14.5 |
| zeptun-userspace | rr-8x1k | 32459 tps p50=234us p99=472us p99.9=592us | 2 | 9.8% | 90 | 14.5 | 14.4 |
| zeptun-userspace | tcp-down-1 | 12.211 | 2 | 6.7% | 99 | 10.0 | 9.9 |
| zeptun-userspace | tcp-down-10 | 19.689 | 2 | 1.8% | 172 | 18.1 | 14.4 |
| zeptun-userspace | tcp-up-1 | 18.681 | 2 | 1.3% | 85 | 11.0 | 7.8 |
| zeptun-userspace | tcp-up-10 | 21.483 | 2 | 1.2% | 125 | 16.1 | 9.9 |
| zeptun-userspace | udp-100k | 77644 echo pps (77.6% of 100000 sent) | 2 | 4.5% | 73 | 17.7 | 16.8 |
| zeptun-userspace | udp-gso-100k | 82751 echo pps (82.8% of 99975 sent) | 2 | 0.9% | 58 | 17.7 | 16.8 |

## Throughput by engine (best tier each engine reached)

| engine | queues | scenario | median |
|---|---:|---|---:|
| hev | 1 | crr | 1761 tps p50=552us p99=624us p99.9=664us |
| hev | 1 | rr | 7219 tps p50=138us p99=170us p99.9=184us |
| hev | 1 | rr-8x1k | 31661 tps p50=228us p99=584us p99.9=736us |
| hev | 1 | tcp-down-1 | 6.484 |
| hev | 1 | tcp-down-10 | 11.053 |
| hev | 1 | tcp-up-1 | 5.994 |
| hev | 1 | tcp-up-10 | 13.377 |
| hev | 1 | udp-100k | 75683 echo pps (75.7% of 99975 sent) |
| hev | 1 | udp-gso-100k | 74907 echo pps (74.9% of 99984 sent) |
| zeptun-hybrid | 1 | crr | 1562 tps p50=624us p99=728us p99.9=832us |
| zeptun-hybrid | 1 | rr | 6594 tps p50=146us p99=184us p99.9=200us |
| zeptun-hybrid | 1 | rr-8x1k | 30213 tps p50=252us p99=568us p99.9=912us |
| zeptun-hybrid | 1 | tcp-down-1 | 12.773 |
| zeptun-hybrid | 1 | tcp-down-10 | 23.181 |
| zeptun-hybrid | 1 | tcp-up-1 | 11.844 |
| zeptun-hybrid | 1 | tcp-up-10 | 19.655 |
| zeptun-hybrid | 1 | udp-100k | 79905 echo pps (79.9% of 100000 sent) |
| zeptun-hybrid | 1 | udp-gso-100k | 81079 echo pps (81.1% of 99975 sent) |
| zeptun-userspace | 1 | crr | 2006 tps p50=484us p99=536us p99.9=656us |
| zeptun-userspace | 1 | rr | 7084 tps p50=136us p99=172us p99.9=188us |
| zeptun-userspace | 1 | rr-8x1k | 32459 tps p50=234us p99=472us p99.9=592us |
| zeptun-userspace | 1 | tcp-down-1 | 12.211 |
| zeptun-userspace | 1 | tcp-down-10 | 19.689 |
| zeptun-userspace | 1 | tcp-up-1 | 18.681 |
| zeptun-userspace | 1 | tcp-up-10 | 21.483 |
| zeptun-userspace | 1 | udp-100k | 77644 echo pps (77.6% of 100000 sent) |
| zeptun-userspace | 1 | udp-gso-100k | 82751 echo pps (82.8% of 99975 sent) |

zeptun: startup 3 ms, idle 844 KB, 4 wakeups in 20 s | tcp 1000: 8100 KB (conns: 1000/1000 established, 0 failed, 1842 conn/s) | udp 1000: 5384 KB (udp flows: 1000/1000 answered, 8576 flows/s)
hev: startup 3 ms, idle 2221 KB, 2 wakeups in 20 s | tcp 1000: 78798 KB (conns: 1000/1000 established, 0 failed, 1924 conn/s) | udp 1000: 27302 KB (udp flows: 1000/1000 answered, 5635 flows/s)
singbox-system: startup 49 ms, idle 58481 KB, 7 wakeups in 20 s | tcp 1000: 73584 KB (conns: 1000/1000 established, 0 failed, 1347 conn/s) | udp 1000: 68368 KB (udp flows: 0/1000 answered, 0 flows/s)
singbox-gvisor: startup 51 ms, idle 58409 KB, 123 wakeups in 20 s | tcp 1000: 97292 KB (conns: 1000/1000 established, 0 failed, 1255 conn/s) | udp 1000: 96476 KB (udp flows: 0/1000 answered, 0 flows/s)
tun2socks: startup 5 ms, idle 13856 KB, 260 wakeups in 20 s | tcp 1000: 109288 KB (conns: 1000/1000 established, 0 failed, 1211 conn/s) | udp 1000: 183824 KB (udp flows: 1000/1000 answered, 5026 flows/s)
