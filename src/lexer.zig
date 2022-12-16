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

    fn nextToken(self: *@This()) !Token {
        if (self.offset >= self.input.len)
            return Token.init(.eof);

        switch (self.input[self.offset]) {
            '(' => {
                self.offset += 1;
                return Token.init(.open_brace);
            },
            else => return error.NotImplemented,
        }
    }

    pub fn lex(self: *@This()) ![]Token {
        var tokens = std.ArrayList(Token).init(self.arena.allocator());
        while (true) {
            const token = try self.nextToken();
            try tokens.append(token);

            if (token.kind == .eof) break;
        }
        return try tokens.toOwnedSlice();
    }
};

test "lex empty" {
    var lexer = Lexer.init(std.testing.allocator, "");
    defer lexer.deinit();

    const tokens = try lexer.lex();
    try std.testing.expectEqual(@as(usize, 1), tokens.len);
    try std.testing.expectEqual(Token.Kind.eof, tokens[0].kind);
}

test "lex simple" {
    var lexer = Lexer.init(std.testing.allocator, "(");
    defer lexer.deinit();

    const tokens = try lexer.lex();
    try std.testing.expectEqual(@as(usize, 2), tokens.len);
    try std.testing.expectEqual(Token.Kind.open_brace, tokens[0].kind);
    try std.testing.expectEqual(Token.Kind.eof, tokens[1].kind);
}
