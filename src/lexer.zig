const std = @import("std");
const Token = @import("token.zig").Token;

pub const Lexer = struct {
    arena: std.heap.ArenaAllocator,
    input: []const u8,
    offset: usize = 0,
    tokens: std.ArrayList(Token),

    pub fn init(a: std.mem.Allocator, input: []const u8) @This() {
        var result = @This(){
            .arena = std.heap.ArenaAllocator.init(a),
            .input = input,
            .tokens = undefined,
        };
        result.tokens = std.ArrayList(Token).init(result.arena.allocator());
        return result;
    }

    pub fn deinit(self: @This()) void {
        self.arena.deinit();
    }

    pub fn nextToken(self: *@This()) !Token {
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
};

test "lex empty" {
    var lexer = Lexer.init(std.testing.allocator, "");
    defer lexer.deinit();

    const token = try lexer.nextToken();
    try std.testing.expectEqual(Token.Kind.eof, token.kind);
}

test "lex simple" {
    var lexer = Lexer.init(std.testing.allocator, "(");
    defer lexer.deinit();

    const token = try lexer.nextToken();
    try std.testing.expectEqual(Token.Kind.open_brace, token.kind);
}
