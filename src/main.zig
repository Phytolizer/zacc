const std = @import("std");

pub fn main() !void {}

test {
    try std.fs.cwd().access("src/tests/README.md", .{});
    std.testing.refAllDeclsRecursive(@import("parser.zig"));
    try @import("test.zig").run(1);
}
