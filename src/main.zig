const std = @import("std");

pub fn main() !void {}

test {
    std.testing.refAllDeclsRecursive(@import("lexer.zig"));
    try @import("test.zig").run(1);
}
