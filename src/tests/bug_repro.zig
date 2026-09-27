const std = @import("std");
const testing = std.testing;

test "C3: fillRandom produces different outputs on fallback path" {
    const Engine = @import("../engine.zig").Engine;

    var buf1: [32]u8 = undefined;
    var buf2: [32]u8 = undefined;

    Engine.fillRandom(&buf1);
    Engine.fillRandom(&buf2);

    var same: usize = 0;
    for (buf1, buf2) |a, b| {
        if (a == b) same += 1;
    }

    try testing.expect(same < 32);
}

test "C3: fillRandom output is not all zeros" {
    const Engine = @import("../engine.zig").Engine;

    var buf: [64]u8 = undefined;
    Engine.fillRandom(&buf);

    var all_zero: bool = true;
    for (buf) |b| {
        if (b != 0) {
            all_zero = false;
            break;
        }
    }

    try testing.expect(!all_zero);
}

test "C3: fillRandom produces different sequences" {
    const Engine = @import("../engine.zig").Engine;

    var buf1: [128]u8 = undefined;
    var buf2: [128]u8 = undefined;

    Engine.fillRandom(&buf1);
    Engine.fillRandom(&buf2);

    var diff: usize = 0;
    for (buf1, buf2) |a, b| {
        if (a != b) diff += 1;
    }

    try testing.expect(diff > 0);
}
