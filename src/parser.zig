const std = @import("std");
const Lexer = @import("lexer.zig").Lexer;
const Token = @import("token.zig").Token;

pub const Parser = struct {
    lexer: Lexer,
    tokens: []const Token,

    pub fn init(a: std.mem.Allocator, source: []const u8) !@This() {
        var result: @This() = undefined;
        result.lexer = Lexer.init(a, source);
        result.tokens = try result.lexer.lex();
        return result;
    }
};
