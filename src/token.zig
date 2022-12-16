const std = @import("std");

pub const Token = struct {
    kind: Kind,

    pub const Kind = union(enum) {
        int,
        ident: []u8,
        open_paren,
        close_paren,
        open_brace,
        @"return",
        constant: i32,
        semicolon,
        close_brace,
        eof,

        pub fn format(
            self: @This(),
            comptime _: []const u8,
            _: std.fmt.FormatOptions,
            writer: anytype,
        ) !void {
            const text = switch (self) {
                .int => "int",
                .ident => |i| i,
                .open_paren => "(",
                .close_paren => ")",
                .open_brace => "{",
                .@"return" => "return",
                .semicolon => ";",
                .close_brace => "}",
                .eof => "eof",

                // special handling
                .constant => |c| return writer.print("{d}", .{c}),
            };
            return writer.writeAll(text);
        }
    };

    pub fn init(kind: Kind) @This() {
        return .{ .kind = kind };
    }
};

test "init/deinit" {
    var t = Token.init(.{ .constant = 69 });
    var buf = [_]u8{0} ** 10;
    try std.testing.expectEqualStrings(
        "69",
        try std.fmt.bufPrint(&buf, "{}", .{t.kind}),
    );
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    t = Token.init(.{ .ident = try arena.allocator().dupe(u8, "hello") });
    try std.testing.expectEqualStrings(
        "hello",
        try std.fmt.bufPrint(&buf, "{}", .{t.kind}),
    );
}
