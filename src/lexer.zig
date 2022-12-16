const std = @import("std");
const Token = @import("token.zig").Token;

pub const Lexer = struct {
    arena: std.heap.ArenaAllocator,
    input: []const u8,
    offset: usize = 0,

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
        self.offset += 1;
    }

    fn nextToken(self: *@This()) !Token {
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
                else => if (std.ascii.isAlphabetic(c) or c == '_') {
                    const start = self.offset;
                    while (self.get()) |c2| {
                        if (!std.ascii.isAlphanumeric(c2) and c2 != '_') break;
                        self.next();
                    }
                    const keywords = std.ComptimeStringMap(Token, .{
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
                    std.debug.print("error: can't handle character: {c}\n", .{c});
                    return error.NotImplemented;
                },
            }
        } else return .eof;
    }

    pub fn lex(self: *@This()) ![]Token {
        var tokens = std.ArrayList(Token).init(self.arena.allocator());
        while (true) {
            const token = try self.nextToken();
            try tokens.append(token);

            if (token == .eof) break;
        }
        return try tokens.toOwnedSlice();
    }
};

test "lex empty" {
    var lexer = Lexer.init(std.testing.allocator, "");
    defer lexer.deinit();

    const tokens = try lexer.lex();
    try std.testing.expectEqual(@as(usize, 1), tokens.len);
    try std.testing.expectEqual(Token.eof, tokens[0]);
}

test "lex simple" {
    var lexer = Lexer.init(std.testing.allocator, "(");
    defer lexer.deinit();

    const tokens = try lexer.lex();
    try std.testing.expectEqual(@as(usize, 2), tokens.len);
    try std.testing.expectEqual(Token.open_paren, tokens[0]);
    try std.testing.expectEqual(Token.eof, tokens[1]);
}
