const std = @import("std");

pub const Token = struct {
    a: std.mem.Allocator,
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

        pub fn deinit(self: @This(), a: std.mem.Allocator) void {
            switch (self) {
                .ident => |i| a.free(i),
                else => {},
            }
        }

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
                .constant => |c| return writer.print("{d}", .{c}),
            };
            return writer.writeAll(text);
        }
    };

    pub fn init(a: std.mem.Allocator, kind: Kind) @This() {
        return .{
            .a = a,
            .kind = kind,
        };
    }

    pub fn deinit(self: @This()) void {
        self.kind.deinit(self.a);
    }
};
