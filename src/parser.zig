const std = @import("std");
const ast = @import("ast.zig");
const Lexer = @import("lexer.zig").Lexer;
const Token = @import("token.zig").Token;

pub const Parser = struct {
    lexer: Lexer,
    tokens: []const Token,
    pos: usize,

    pub fn init(a: std.mem.Allocator, source: []const u8) !@This() {
        var result: @This() = undefined;
        result.lexer = Lexer.init(a, source);
        result.tokens = try result.lexer.lex();
        result.pos = 0;
        return result;
    }

    pub fn deinit(self: @This()) void {
        self.lexer.deinit();
    }

    fn current(self: *@This()) Token {
        return self.tokens[self.pos];
    }

    fn expect(self: *@This(), kind: Token.Kind) !Token {
        if (self.current().kind() == kind) {
            const result = self.current();
            self.pos += 1;
            return result;
        } else return error.UnexpectedToken;
    }

    fn parseExpression(self: *@This()) !ast.Expression {
        const token = try self.expect(.constant);
        return .{ .value = token.constant };
    }

    fn parseStatement(self: *@This()) !ast.Statement {
        _ = try self.expect(.@"return");
        const expression = try self.parseExpression();
        _ = try self.expect(.semicolon);
        return .{ .return_value = expression };
    }

    fn parseFunction(self: *@This()) !ast.Function {
        _ = try self.expect(.int);
        const name = try self.expect(.ident);
        _ = try self.expect(.open_paren);
        _ = try self.expect(.close_paren);
        _ = try self.expect(.open_brace);
        const statement = try self.parseStatement();
        _ = try self.expect(.close_brace);
        return .{
            .name = name.ident,
            .statement = statement,
        };
    }

    pub fn parse(self: *@This()) !ast.Program {
        return .{ .function = try self.parseFunction() };
    }
};
