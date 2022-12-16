const std = @import("std");

pub fn main() !void {}

test {
    try @import("test.zig").run(1);
    const token = @import("token.zig");
    const t = token.Token.init(std.testing.allocator, .{ .constant = 69 });
    defer t.deinit();
    const text = try std.fmt.allocPrint(std.testing.allocator, "{}", .{t.kind});
    defer std.testing.allocator.free(text);
    try std.testing.expectEqualStrings(text, "69");
}
