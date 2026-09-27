const std = @import("std");
const builtin = @import("builtin");
const zeptun = @import("zeptun");

const checksum = zeptun.packet.checksum;
const parse = zeptun.packet.parse;
const pool = zeptun.packet.pool;
const gso = zeptun.packet.gso;
const table = zeptun.flow.table;
const timeouts = zeptun.flow.timeouts;
const nat = zeptun.flow.nat;
const ip = zeptun.stack.ip;
const sys = zeptun.io.sys;

pub const Result = struct {
    name: []const u8,
    group: []const u8,
    ns_per_op: f64,
    ops_per_sec: f64,
    mb_per_sec: f64,
    bytes_per_op: u64,
    ns_per_op_spread_pct: f64 = 0,
    digest: u64 = 0,
};

pub const Options = struct {
    min_ns: u64 = 300 * std.time.ns_per_ms,
    json_path: ?[]const u8 = null,
    markdown_path: ?[]const u8 = null,
    svg_path: ?[]const u8 = null,
    baseline_path: ?[]const u8 = null,
    max_regression_pct: f64 = 15.0,
    filter: ?[]const u8 = null,
    reps: u32 = 5,
    update_golden: bool = false,
    allow_debug: bool = false,
};

pub const BuildMode = @tagName(builtin.mode);

const Runner = struct {
    allocator: std.mem.Allocator,
    results: std.ArrayList(Result) = .empty,
    opts: Options,
    identity_failures: u32 = 0,

    fn sampleOnce(ctx: anytype, comptime f: fn (@TypeOf(ctx)) void, min_ns: u64) f64 {
        var warm: u32 = 0;
        while (warm < 1000) : (warm += 1) f(ctx);
        var iterations: u64 = 0;
        var batch: u64 = 64;
        const start = sys.monotonicNs();
        var elapsed: u64 = 0;
        while (elapsed < min_ns) {
            var i: u64 = 0;
            while (i < batch) : (i += 1) f(ctx);
            iterations += batch;
            elapsed = sys.monotonicNs() - start;
            if (elapsed < min_ns / 8) batch *= 2;
        }
        return @as(f64, @floatFromInt(elapsed)) / @as(f64, @floatFromInt(iterations));
    }

    fn run(
        r: *Runner,
        group: []const u8,
        name: []const u8,
        bytes_per_op: u64,
        ctx: anytype,
        comptime f: fn (@TypeOf(ctx)) void,
        comptime digest: ?fn (@TypeOf(ctx)) u64,
    ) !void {
        if (r.opts.filter) |flt| {
            if (std.mem.indexOf(u8, name, flt) == null) return;
        }
        var got: u64 = 0;
        if (digest) |dg| {
            got = dg(ctx);
            if (r.opts.update_golden) {
                std.debug.print("GOLDEN .{{ \"{s}\", 0x{x:0>16} }},\n", .{ name, got });
            } else if (golden.get(name)) |want| {
                if (got != want) {
                    r.identity_failures += 1;
                    std.debug.print("IDENTITY {s:<40} want 0x{x:0>16} got 0x{x:0>16}\n", .{ name, want, got });
                } else {
                    std.debug.print("identity {s:<40} 0x{x:0>16} ok\n", .{ name, got });
                }
            }
        }
        const samples = try r.allocator.alloc(f64, @max(r.opts.reps, 1));
        defer r.allocator.free(samples);
        for (samples) |*s| s.* = sampleOnce(ctx, f, r.opts.min_ns);
        var best = samples[0];
        var worst = samples[0];
        for (samples) |s| {
            if (s < best) best = s;
            if (s > worst) worst = s;
        }
        const ns_per_op = best;
        const ops = 1e9 / ns_per_op;
        try r.results.append(r.allocator, .{
            .name = name,
            .group = group,
            .ns_per_op = ns_per_op,
            .ops_per_sec = ops,
            .mb_per_sec = if (bytes_per_op > 0) ops * @as(f64, @floatFromInt(bytes_per_op)) / 1e6 else 0,
            .bytes_per_op = bytes_per_op,
            .ns_per_op_spread_pct = if (worst > 0) (worst - best) / best * 100.0 else 0,
            .digest = got,
        });
        std.debug.print("{s:<40} {d:>12.2} ns/op {d:>14.0} ops/s", .{ name, ns_per_op, ops });
        if (bytes_per_op > 0) std.debug.print(" {d:>10.1} MB/s", .{ops * @as(f64, @floatFromInt(bytes_per_op)) / 1e6});
        std.debug.print("  [spread {d:.1}%]\n", .{(worst - best) / best * 100.0});
    }
};

const golden = std.StaticStringMap(u64).initComptime(.{
    .{ "checksum/scalar/64", 0x6e6710fba79cafa3 },
    .{ "checksum/simd/64", 0x6e6710fba79cafa3 },
    .{ "checksum/scalar/128", 0x61785d06f4c3202a },
    .{ "checksum/simd/128", 0x61785d06f4c3202a },
    .{ "checksum/scalar/256", 0x2337fa02a75ca72c },
    .{ "checksum/simd/256", 0x2337fa02a75ca72c },
    .{ "checksum/scalar/512", 0xc97c051422450f08 },
    .{ "checksum/simd/512", 0xc97c051422450f08 },
    .{ "checksum/scalar/1500", 0x1d92ce84cc9dc8b4 },
    .{ "checksum/simd/1500", 0x1d92ce84cc9dc8b4 },
    .{ "checksum/scalar/9000", 0x1dfd7c83a0580701 },
    .{ "checksum/simd/9000", 0x1dfd7c83a0580701 },
    .{ "checksum/scalar/65535", 0x6bb31eeb4ca62677 },
    .{ "checksum/simd/65535", 0x6bb31eeb4ca62677 },
    .{ "parse/ip-only", 0xd6753cdc658ede03 },
    .{ "parse/ip+tcp", 0xe9a10070233295ea },
    .{ "parse/+flowkey", 0xbe6415f8c9743986 },
    .{ "parse/flowkey-hash", 0xfa5f601550f1c802 },
    .{ "parse/ipv4-tcp+flowkey", 0x12402e5ea08ef373 },
    .{ "flow-table/lookup-60k", 0xa78fcef817dd7851 },
    .{ "flow-table/remove+insert-60k", 0xa78fcef817dd7851 },
    .{ "nat/rewrite-64k-full-csum", 0xbf45fc54d10284dc },
    .{ "nat/rewrite-64k-partial-csum", 0xe34102ea1cfdc808 },
    .{ "gso/split-64k-mss1460", 0x16e0da5a494b8072 },
    .{ "gro/coalesce-40x1460", 0xdddb228852b637e5 },
});

fn mix(seed: u64, v: u64) u64 {
    var h = seed ^ (v *% 0xff51_afd7_ed55_8ccd);
    h ^= h >> 33;
    h *%= 0xc4ce_b9fe_1a85_ec53;
    h ^= h >> 29;
    return h;
}

fn mixBytes(seed: u64, bytes: []const u8) u64 {
    var h = seed;
    var i: usize = 0;
    while (i + 8 <= bytes.len) : (i += 8) h = mix(h, std.mem.readInt(u64, bytes[i..][0..8], .little));
    while (i < bytes.len) : (i += 1) h = mix(h, bytes[i]);
    return h;
}

const ChecksumCtx = struct {
    data: []const u8,
    impl: checksum.Impl,

    fn call(c: *const ChecksumCtx) void {
        const v = checksum.finish(switch (c.impl) {
            .scalar => checksum.sumScalar(c.data, 0),
            .simd => checksum.sumSimd(c.data, 0),
        });
        std.mem.doNotOptimizeAway(v);
    }

    fn digest(c: *const ChecksumCtx) u64 {
        const s1 = checksum.finish(checksum.sumScalar(c.data, 0));
        const s2 = checksum.finish(checksum.sumSimd(c.data, 0));
        if (s1 != s2) {
            std.debug.print("scalar/simd divergence on {d} bytes: 0x{x} vs 0x{x}\n", .{ c.data.len, s1, s2 });
        }
        return mix(mix(0x5ca1_ab1e, s1), s2);
    }
};

const ParseCtx = struct {
    data: []const u8,

    fn call(c: *const ParseCtx) void {
        const p = parse.parse(c.data) catch unreachable;
        const k = parse.FlowKey.fromPacket(c.data, p);
        std.mem.doNotOptimizeAway(k.hash());
    }

    fn digest(c: *const ParseCtx) u64 {
        const p = parse.parse(c.data) catch unreachable;
        const k = parse.FlowKey.fromPacket(c.data, p);
        return mix(mix(mix(0x9a1e, @as(u64, p.l4_off)), @as(u64, p.payload_len)), k.hash());
    }
};

const ParseIpCtx = struct {
    data: []const u8,

    fn call(c: *const ParseIpCtx) void {
        const hdr = parse.parseIp(c.data) catch unreachable;
        std.mem.doNotOptimizeAway(hdr.total_len);
    }

    fn digest(c: *const ParseIpCtx) u64 {
        const hdr = parse.parseIp(c.data) catch unreachable;
        return mix(0x1b1d, @as(u64, hdr.total_len) | (@as(u64, hdr.header_len) << 16) | (@as(u64, hdr.next) << 32));
    }
};

const ParseFullCtx = struct {
    data: []const u8,

    fn call(c: *const ParseFullCtx) void {
        const p = parse.parse(c.data) catch unreachable;
        std.mem.doNotOptimizeAway(p.payload_len);
    }

    fn digest(c: *const ParseFullCtx) u64 {
        const p = parse.parse(c.data) catch unreachable;
        return mix(mix(0x2b2e, @as(u64, p.l4_off)), @as(u64, p.payload_len));
    }
};

const FlowKeyCtx = struct {
    data: []const u8,
    key: parse.FlowKey = .{},

    fn call(c: *FlowKeyCtx) void {
        const p = parse.parse(c.data) catch unreachable;
        c.key = parse.FlowKey.fromPacket(c.data, p);
        std.mem.doNotOptimizeAway(c.key.src[0]);
    }

    fn digest(c: *FlowKeyCtx) u64 {
        c.call();
        return mixBytes(0x3c3f, std.mem.asBytes(&c.key));
    }
};

const HashCtx = struct {
    key: parse.FlowKey,

    fn call(c: *const HashCtx) void {
        std.mem.doNotOptimizeAway(c.key.hash());
    }

    fn digest(c: *const HashCtx) u64 {
        return mix(0x4d40, c.key.hash());
    }
};

const TableCtx = struct {
    t: *table.FlowTable(u64),
    keys: []parse.FlowKey,
    i: usize = 0,

    fn lookup(c: *TableCtx) void {
        const k = &c.keys[c.i % c.keys.len];
        c.i +%= 7;
        std.mem.doNotOptimizeAway(c.t.find(k));
    }

    fn churn(c: *TableCtx) void {
        const k = c.keys[c.i % c.keys.len];
        c.i +%= 1;
        if (c.t.find(&k)) |idx| {
            c.t.remove(idx);
            _ = c.t.insert(k, 1) catch unreachable;
        }
    }

    fn digest(c: *TableCtx) u64 {
        var h: u64 = 0xc0ffee;
        for (c.keys[0..256], 0..) |*k, i| {
            const found = c.t.find(k);
            h = mix(h, @as(u64, @intFromBool(found != null)) | (@as(u64, if (found) |idx| idx + 1 else 0) << 1) ^ @as(u64, @intCast(i)));
        }
        return h;
    }
};

const PoolCtx = struct {
    p: *pool.Pool,
    held: [16]*pool.Buffer = undefined,

    fn call(c: *PoolCtx) void {
        for (&c.held) |*h| h.* = c.p.get().?;
        for (c.held) |h| c.p.put(h);
    }
};

const WheelCtx = struct {
    wheel: *timeouts.Wheel,
    timers: []timeouts.Timer,
    i: usize = 0,

    fn call(c: *WheelCtx) void {
        const t = &c.timers[c.i % c.timers.len];
        c.i +%= 1;
        c.wheel.schedule(t, c.wheel.now + 200 + (c.i % 5000));
        if (c.i % 3 == 0) c.wheel.cancel(t);
    }
};

const NatCtx = struct {
    data: []u8,
    partial: bool,
    flip: bool = false,

    fn call(c: *NatCtx) void {
        const p = parse.parse(c.data) catch unreachable;
        c.flip = !c.flip;
        const a = [4]u8{ 172, 19, 0, 2 };
        const b = [4]u8{ 10, 0, 0, 1 };
        nat.rewrite(c.data, p, .{
            .src = if (c.flip) &a else &b,
            .dst = if (c.flip) &b else &a,
            .src_port = if (c.flip) 20001 else 40000,
            .dst_port = if (c.flip) 7000 else 443,
        }, c.partial);
    }

    fn digest(c: *NatCtx) u64 {
        c.call();
        return mixBytes(0x0a7ec, c.data);
    }
};

const SegmentCtx = struct {
    data: []const u8,
    vh: gso.VirtioNetHdr,
    out: []u8,

    fn call(c: *SegmentCtx) void {
        var s = gso.Segmenter.init(c.data, c.vh, false) catch unreachable;
        while (s.next(c.out) catch unreachable) |seg| std.mem.doNotOptimizeAway(seg.len);
    }

    fn digest(c: *SegmentCtx) u64 {
        var h: u64 = 0x9e70;
        var s = gso.Segmenter.init(c.data, c.vh, false) catch unreachable;
        while (s.next(c.out) catch unreachable) |seg| h = mixBytes(h, seg);
        return h;
    }
};

const CoalesceCtx = struct {
    p: *pool.Pool,
    segments: [][]u8,

    fn call(c: *CoalesceCtx) void {
        var co: gso.Coalescer(8) = .{};
        for (c.segments) |s| {
            const b = c.p.get().?;
            @memcpy(b.tail()[0..s.len], s);
            b.len = @intCast(s.len);
            switch (co.add(c.p, b)) {
                .merged, .inserted => {},
                else => c.p.put(b),
            }
        }
        for (co.items[0..co.count]) |*it| {
            std.mem.doNotOptimizeAway(gso.Coalescer(8).finalize(it));
            c.p.put(it.buf);
        }
    }

    fn digest(c: *CoalesceCtx) u64 {
        var co: gso.Coalescer(8) = .{};
        for (c.segments) |s| {
            const b = c.p.get().?;
            @memcpy(b.tail()[0..s.len], s);
            b.len = @intCast(s.len);
            switch (co.add(c.p, b)) {
                .merged, .inserted => {},
                else => c.p.put(b),
            }
        }
        var h: u64 = 0xc0a1e;
        for (co.items[0..co.count]) |*it| {
            const vh = gso.Coalescer(8).finalize(it);
            h = mix(mixBytes(h, it.buf.bytes()), vh.gso_size);
            c.p.put(it.buf);
        }
        return h;
    }
};

fn buildTcp(buf: []u8, payload_len: usize, seq: u32) []u8 {
    const total = 40 + payload_len;
    ip.writeIpv4(buf, &[_]u8{ 10, 0, 0, 1 }, &[_]u8{ 93, 184, 216, 34 }, parse.proto.tcp, @intCast(20 + payload_len), 64, 0, 1);
    parse.setBe16(buf, 20, 40000);
    parse.setBe16(buf, 22, 443);
    parse.setBe32(buf, 24, seq);
    parse.setBe32(buf, 28, 1);
    buf[32] = 0x50;
    buf[33] = 0x10;
    parse.setBe16(buf, 34, 65535);
    @memset(buf[36..40], 0);
    var i: usize = 0;
    while (i < payload_len) : (i += 1) buf[40 + i] = @truncate(i * 31);
    const p = parse.parseIp(buf[0..total]) catch unreachable;
    gso.setFullChecksum(buf[0..total], p, parse.proto.tcp, 36);
    return buf[0..total];
}

pub fn runAll(allocator: std.mem.Allocator, io: std.Io, opts: Options) !u8 {
    if (builtin.mode != .ReleaseFast and !opts.allow_debug) {
        std.debug.print("refusing to report {s} microbenchmarks: build mode is {s}, expected ReleaseFast\npass --allow-debug to override\n", .{ BuildMode, BuildMode });
        return 2;
    }
    std.debug.print("zeptun-bench micro: {t}-{t} mode={s} zig={s} cpus={d} reps={d} min_ns={d}\n", .{ builtin.cpu.arch, builtin.os.tag, BuildMode, builtin.zig_version_string, sys.cpuCount(), @max(opts.reps, 1), opts.min_ns });
    var r: Runner = .{ .allocator = allocator, .opts = opts };
    defer r.results.deinit(allocator);
    var prng = std.Random.DefaultPrng.init(0xbe7c);
    const rand = prng.random();
    const sizes = [_]usize{ 64, 128, 256, 512, 1500, 9000, 65535 };
    const data = try allocator.alloc(u8, 65536);
    defer allocator.free(data);
    rand.bytes(data);
    for (sizes) |sz| {
        for ([_]checksum.Impl{ .scalar, .simd }) |impl| {
            const ctx: ChecksumCtx = .{ .data = data[0..sz], .impl = impl };
            const name = try std.fmt.allocPrint(allocator, "checksum/{t}/{d}", .{ impl, sz });
            try r.run("checksum", name, sz, &ctx, ChecksumCtx.call, ChecksumCtx.digest);
        }
    }
    var pkt_buf: [70000]u8 = undefined;
    const small_pkt = buildTcp(&pkt_buf, 1400, 1);
    const parse_ctx: ParseCtx = .{ .data = small_pkt };
    var parse_ip_ctx: ParseIpCtx = .{ .data = small_pkt };
    try r.run("parse", "parse/ip-only", 0, &parse_ip_ctx, ParseIpCtx.call, ParseIpCtx.digest);
    var parse_full_ctx: ParseFullCtx = .{ .data = small_pkt };
    try r.run("parse", "parse/ip+tcp", 0, &parse_full_ctx, ParseFullCtx.call, ParseFullCtx.digest);
    var flowkey_ctx: FlowKeyCtx = .{ .data = small_pkt };
    try r.run("parse", "parse/+flowkey", 0, &flowkey_ctx, FlowKeyCtx.call, FlowKeyCtx.digest);
    const p2 = parse.parse(small_pkt) catch unreachable;
    const hash_ctx: HashCtx = .{ .key = parse.FlowKey.fromPacket(small_pkt, p2) };
    try r.run("parse", "parse/flowkey-hash", 0, &hash_ctx, HashCtx.call, HashCtx.digest);
    try r.run("parse", "parse/ipv4-tcp+flowkey", 0, &parse_ctx, ParseCtx.call, ParseCtx.digest);

    var ft = try table.FlowTable(u64).init(allocator, 65536);
    defer ft.deinit(allocator);
    const keys = try allocator.alloc(parse.FlowKey, 60000);
    defer allocator.free(keys);
    for (keys, 0..) |*k, i| {
        k.* = .{ .proto = 6, .src_port = @truncate(i), .dst_port = 443 };
        std.mem.writeInt(u32, k.src[0..4], @intCast(i), .big);
        _ = try ft.insert(k.*, i);
    }
    var tctx: TableCtx = .{ .t = &ft, .keys = keys };
    try r.run("flow", "flow-table/lookup-60k", 0, &tctx, TableCtx.lookup, TableCtx.digest);
    try r.run("flow", "flow-table/remove+insert-60k", 0, &tctx, TableCtx.churn, TableCtx.digest);

    var bp = try pool.Pool.init(allocator, .{ .count = 64, .buffer_size = 70000 });
    defer bp.deinit();
    var pctx: PoolCtx = .{ .p = &bp };
    try r.run("pool", "pool/get+put-x16", 0, &pctx, PoolCtx.call, null);

    var wheel = timeouts.Wheel.init(1000);
    const timers = try allocator.alloc(timeouts.Timer, 4096);
    defer allocator.free(timers);
    for (timers) |*t| t.* = .{};
    var wctx: WheelCtx = .{ .wheel = &wheel, .timers = timers };
    try r.run("timer", "timer-wheel/schedule+cancel", 0, &wctx, WheelCtx.call, null);

    var nat_buf: [70000]u8 = undefined;
    const super = buildTcp(&nat_buf, 64000, 5);
    var nctx: NatCtx = .{ .data = super, .partial = false };
    try r.run("nat", "nat/rewrite-64k-full-csum", 0, &nctx, NatCtx.call, NatCtx.digest);
    nctx.partial = true;
    try r.run("nat", "nat/rewrite-64k-partial-csum", 0, &nctx, NatCtx.call, NatCtx.digest);

    var seg_out: [2000]u8 = undefined;
    var sctx: SegmentCtx = .{ .data = super, .vh = gso.VirtioNetHdr.tcp(false, 20, 20, 1460, false), .out = &seg_out };
    try r.run("gso", "gso/split-64k-mss1460", super.len, &sctx, SegmentCtx.call, SegmentCtx.digest);

    var co_pool = try pool.Pool.init(allocator, .{ .count = 128, .buffer_size = 70000 });
    defer co_pool.deinit();
    const segs = try allocator.alloc([]u8, 40);
    defer allocator.free(segs);
    const seg_storage = try allocator.alloc(u8, 40 * 1500);
    defer allocator.free(seg_storage);
    for (segs, 0..) |*s, i| {
        s.* = buildTcp(seg_storage[i * 1500 ..][0..1500], 1460, 1 + @as(u32, @intCast(i)) * 1460);
    }
    var cctx: CoalesceCtx = .{ .p = &co_pool, .segments = segs };
    const coalesced_bytes: u64 = 40 * 1460;
    const staged_bytes: u64 = 40 * 1500;
    try r.run("gso", "gro/coalesce-40x1460", coalesced_bytes + staged_bytes, &cctx, CoalesceCtx.call, CoalesceCtx.digest);

    if (r.identity_failures > 0) {
        std.debug.print("{d} benchmark(s) produced non-identical output; refusing to report timings\n", .{r.identity_failures});
        return 3;
    }
    if (opts.json_path) |path| try writeJson(allocator, io, path, r.results.items);
    if (opts.markdown_path) |path| try writeMarkdown(allocator, io, path, r.results.items);
    if (opts.svg_path) |path| try writeSvg(allocator, io, path, r.results.items);
    if (opts.baseline_path) |path| return try gate(allocator, io, path, r.results.items, opts.max_regression_pct);
    return 0;
}

fn ensureParent(io: std.Io, path: []const u8) void {
    if (std.fs.path.dirname(path)) |dir| {
        std.Io.Dir.cwd().createDirPath(io, dir) catch {};
    }
}

fn writeAll(allocator: std.mem.Allocator, io: std.Io, path: []const u8, bytes: []const u8) !void {
    _ = allocator;
    ensureParent(io, path);
    try std.Io.Dir.cwd().writeFile(io, .{ .sub_path = path, .data = bytes });
}

fn writeJson(allocator: std.mem.Allocator, io: std.Io, path: []const u8, results: []const Result) !void {
    var out: std.Io.Writer.Allocating = .init(allocator);
    defer out.deinit();
    const w = &out.writer;
    try w.print("{{\n  \"tool\": \"zeptun-bench\",\n  \"version\": \"{s}\",\n  \"zig\": \"{s}\",\n  \"arch\": \"{t}\",\n  \"os\": \"{t}\",\n  \"mode\": \"{s}\",\n  \"cpus\": {d},\n  \"results\": [\n", .{ zeptun.version, builtin.zig_version_string, builtin.cpu.arch, builtin.os.tag, BuildMode, sys.cpuCount() });
    for (results, 0..) |res, i| {
        try w.print("    {{\"name\": \"{s}\", \"group\": \"{s}\", \"ns_per_op\": {d:.3}, \"ops_per_sec\": {d:.1}, \"mb_per_sec\": {d:.2}, \"bytes_per_op\": {d}, \"spread_pct\": {d:.1}, \"digest\": \"0x{x:0>16}\"}}{s}\n", .{ res.name, res.group, res.ns_per_op, res.ops_per_sec, res.mb_per_sec, res.bytes_per_op, res.ns_per_op_spread_pct, res.digest, if (i + 1 < results.len) "," else "" });
    }
    try w.writeAll("  ]\n}\n");
    try writeAll(allocator, io, path, out.written());
}

fn writeMarkdown(allocator: std.mem.Allocator, io: std.Io, path: []const u8, results: []const Result) !void {
    var out: std.Io.Writer.Allocating = .init(allocator);
    defer out.deinit();
    const w = &out.writer;
    try w.print("# zeptun-bench micro ({t}-{t}, {s}, zig {s}, {d} cpus)\n\nnumbers are the minimum of the repetitions; higher spread means noisier host.\n\n| benchmark | ns/op | ops/s | MB/s | spread |\n|---|---:|---:|---:|---:|\n", .{ builtin.cpu.arch, builtin.os.tag, BuildMode, builtin.zig_version_string, sys.cpuCount() });
    for (results) |res| {
        if (res.bytes_per_op > 0) {
            try w.print("| {s} | {d:.2} | {d:.0} | {d:.1} | {d:.1}% |\n", .{ res.name, res.ns_per_op, res.ops_per_sec, res.mb_per_sec, res.ns_per_op_spread_pct });
        } else {
            try w.print("| {s} | {d:.2} | {d:.0} | - | {d:.1}% |\n", .{ res.name, res.ns_per_op, res.ops_per_sec, res.ns_per_op_spread_pct });
        }
    }
    try writeAll(allocator, io, path, out.written());
}

fn writeSvg(allocator: std.mem.Allocator, io: std.Io, path: []const u8, results: []const Result) !void {
    var out: std.Io.Writer.Allocating = .init(allocator);
    defer out.deinit();
    const w = &out.writer;
    const row: usize = 22;
    const height = 40 + results.len * row;
    try w.print("<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"900\" height=\"{d}\" font-family=\"monospace\" font-size=\"12\">\n<rect width=\"100%\" height=\"100%\" fill=\"#ffffff\"/>\n<text x=\"10\" y=\"20\" font-size=\"14\">zeptun-bench micro: bar length is log10(ops/s)</text>\n", .{height});
    for (results, 0..) |res, i| {
        const y = 32 + i * row;
        const scale = @max(std.math.log10(@max(res.ops_per_sec, 1.0)), 0.0) / 9.0;
        const width: usize = @intFromFloat(@min(scale, 1.0) * 520.0);
        try w.print("<text x=\"10\" y=\"{d}\">{s}</text><rect x=\"300\" y=\"{d}\" width=\"{d}\" height=\"14\" fill=\"#3b82f6\"/><text x=\"{d}\" y=\"{d}\">{d:.0}/s</text>\n", .{ y + 12, res.name, y, width, 306 + width, y + 12, res.ops_per_sec });
    }
    try w.writeAll("</svg>\n");
    try writeAll(allocator, io, path, out.written());
}

const Baseline = struct {
    results: []const struct {
        name: []const u8,
        ns_per_op: f64,
    },
};

fn gate(allocator: std.mem.Allocator, io: std.Io, path: []const u8, results: []const Result, max_pct: f64) !u8 {
    const bytes = std.Io.Dir.cwd().readFileAlloc(io, path, allocator, .limited(4 << 20)) catch |err| {
        std.debug.print("baseline {s} unreadable: {t}\n", .{ path, err });
        return 1;
    };
    defer allocator.free(bytes);
    const parsed = try std.json.parseFromSlice(Baseline, allocator, bytes, .{ .ignore_unknown_fields = true });
    defer parsed.deinit();
    var failed: u32 = 0;
    for (results) |res| {
        for (parsed.value.results) |base| {
            if (!std.mem.eql(u8, base.name, res.name)) continue;
            const delta = (res.ns_per_op - base.ns_per_op) / base.ns_per_op * 100.0;
            const verdict = if (delta > max_pct) "REGRESSION" else "ok";
            if (delta > max_pct) failed += 1;
            std.debug.print("gate {s:<40} baseline {d:>10.2} ns current {d:>10.2} ns delta {d:>7.1}% {s}\n", .{ res.name, base.ns_per_op, res.ns_per_op, delta, verdict });
        }
    }
    if (failed > 0) {
        std.debug.print("{d} benchmark(s) regressed more than {d:.1}%\n", .{ failed, max_pct });
        return 1;
    }
    return 0;
}
