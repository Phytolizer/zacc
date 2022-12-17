const std = @import("std");

pub const Token = struct {
    kind: Kind,
    line: usize,

    pub fn init(kind: Kind, line: usize) @This() {
        return .{ .kind = kind, .line = line };
    }

    pub const Kind = union(Tag) {
        int,
        ident: []const u8,
        open_paren,
        close_paren,
        open_brace,
        @"return",
        constant: i32,
        semicolon,
        close_brace,
        minus,
        tilde,
        bang,

        eof,

        pub const Tag = enum {
            int,
            ident,
            open_paren,
            close_paren,
            open_brace,
            @"return",
            constant,
            semicolon,
            close_brace,
            minus,
            tilde,
            bang,

            eof,

            pub fn format(
                self: @This(),
                comptime _: []const u8,
                _: std.fmt.FormatOptions,
                writer: anytype,
            ) !void {
                const text = std.meta.fieldNames(@This())[@enumToInt(self)];
                for (text) |c| {
                    const out_c = if (c == '_') ' ' else c;
                    try writer.writeAll(&.{out_c});
                }
            }
        };

        pub fn tag(self: @This()) Tag {
            return std.meta.activeTag(self);
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
                .minus => "-",
                .tilde => "~",
                .bang => "!",

                .eof => "eof",

                // special handling
                .constant => |c| return writer.print("{d}", .{c}),
            };
            return writer.writeAll(text);
        }
    };
};
