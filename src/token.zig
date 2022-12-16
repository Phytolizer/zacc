const std = @import("std");

pub const Token = union(Kind) {
    int,
    ident: []const u8,
    open_paren,
    close_paren,
    open_brace,
    @"return",
    constant: i32,
    semicolon,
    close_brace,
    eof,

    pub fn kind(self: @This()) Kind {
        return std.meta.activeTag(self);
    }

    pub const Kind = enum {
        int,
        ident,
        open_paren,
        close_paren,
        open_brace,
        @"return",
        constant,
        semicolon,
        close_brace,
        eof,
    };

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

test "init/deinit" {
    var t = Token{ .constant = 69 };
    var buf = [_]u8{0} ** 10;
    try std.testing.expectEqualStrings(
        "69",
        try std.fmt.bufPrint(&buf, "{}", .{t}),
    );
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    t = Token{ .ident = try arena.allocator().dupe(u8, "hello") };
    try std.testing.expectEqualStrings(
        "hello",
        try std.fmt.bufPrint(&buf, "{}", .{t}),
    );
}
