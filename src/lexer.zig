const std = @import("std");
const Token = @import("token.zig").Token;

pub const Lexer = struct {
    arena: std.heap.ArenaAllocator,
    input: []const u8,
    offset: usize = 0,
    line: usize = 1,

    pub const ErrorInfo = struct {
        message: []u8,
        line: usize,

        pub fn format(
            self: @This(),
            comptime _: []const u8,
            _: std.fmt.FormatOptions,
            writer: anytype,
        ) !void {
            try writer.print("line {d}: {s}", .{ self.line, self.message });
        }
    };

    pub fn init(a: std.mem.Allocator, input: []const u8) @This() {
        var result = @This(){
            .arena = std.heap.ArenaAllocator.init(a),
            .input = input,
        };
        return result;
    }

    pub fn deinit(self: @This()) void {
        self.arena.deinit();
    }

    fn get(self: *const @This()) ?u8 {
        if (self.offset >= self.input.len) return null;
        return self.input[self.offset];
    }

    fn next(self: *@This()) void {
        if (self.get()) |c| {
            if (c == '\n') self.line += 1;
        }
        self.offset += 1;
    }

    fn nextToken(self: *@This(), out_err: *ErrorInfo) !Token.Kind {
        while (self.get()) |c| {
            if (!std.ascii.isWhitespace(c)) break;
            self.next();
        }
        if (self.get()) |c| {
            switch (c) {
                '(' => {
                    self.next();
                    return .open_paren;
                },
                ')' => {
                    self.next();
                    return .close_paren;
                },
                '{' => {
                    self.next();
                    return .open_brace;
                },
                '}' => {
                    self.next();
                    return .close_brace;
                },
                ';' => {
                    self.next();
                    return .semicolon;
                },
                '-' => {
                    self.next();
                    return .minus;
                },
                '~' => {
                    self.next();
                    return .tilde;
                },
                '!' => {
                    self.next();
                    return .bang;
                },
                '+' => {
                    self.next();
                    return .plus;
                },
                '*' => {
                    self.next();
                    return .star;
                },
                '/' => {
                    self.next();
                    return .slash;
                },
                else => if (std.ascii.isAlphabetic(c) or c == '_') {
                    const start = self.offset;
                    while (self.get()) |c2| {
                        if (!std.ascii.isAlphanumeric(c2) and c2 != '_') break;
                        self.next();
                    }
                    const keywords = std.ComptimeStringMap(Token.Kind, .{
                        .{ "int", .int },
                        .{ "return", .@"return" },
                    });
                    const text = self.input[start..self.offset];
                    return keywords.get(text) orelse
                        .{ .ident = try self.arena.allocator().dupe(u8, text) };
                } else if (std.ascii.isDigit(c)) {
                    const start = self.offset;
                    while (self.get()) |c2| {
                        if (!std.ascii.isDigit(c2)) break;
                        self.next();
                    }
                    const text = self.input[start..self.offset];
                    const num = try std.fmt.parseInt(i32, text, 10);
                    return .{ .constant = num };
                } else {
                    out_err.* = .{
                        .message = std.fmt.allocPrint(
                            self.arena.allocator(),
                            "can't handle character: {c}",
                            .{c},
                        ) catch unreachable,
                        .line = self.line,
                    };
                    return error.UnrecognizedToken;
                },
            }
        } else return .eof;
    }

    pub fn lex(self: *@This(), out_err: *ErrorInfo) ![]Token {
        var tokens = std.ArrayList(Token).init(self.arena.allocator());
        while (true) {
            const line = self.line;
            const token_kind = try self.nextToken(out_err);
            const token = Token.init(token_kind, line);
            try tokens.append(token);

            if (token.kind == .eof) break;
        }
        return try tokens.toOwnedSlice();
    }
};
