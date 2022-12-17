const std = @import("std");
const ast = @import("ast.zig");
const Lexer = @import("lexer.zig").Lexer;
const Token = @import("token.zig").Token;

pub const Parser = struct {
    a: std.mem.Allocator,
    lexer: Lexer,
    tokens: []const Token,
    pos: usize,

    pub const Error = error{UnexpectedToken} || std.mem.Allocator.Error;

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

    pub fn init(a: std.mem.Allocator, source: []const u8) !@This() {
        var result: @This() = undefined;
        result.a = a;
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

    fn expect(
        self: *@This(),
        kind: Token.Kind.Tag,
        out_err: *ErrorInfo,
    ) Error!Token {
        if (self.current().kind.tag() == kind) {
            const result = self.current();
            self.pos += 1;
            return result;
        } else {
            out_err.* = .{
                .message = try std.fmt.allocPrint(
                    self.a,
                    "unexpected token \"{}\", expected <{}>",
                    .{ self.current().kind, kind },
                ),
                .line = self.current().line,
            };
            return error.UnexpectedToken;
        }
    }

    fn parseExpression(
        self: *@This(),
        out_err: *ErrorInfo,
    ) Error!ast.Expression {
        const token = try self.expect(.constant, out_err);
        return .{ .value = token.kind.constant };
    }

    fn parseStatement(
        self: *@This(),
        out_err: *ErrorInfo,
    ) Error!ast.Statement {
        _ = try self.expect(.@"return", out_err);
        const expression = try self.parseExpression(out_err);
        _ = try self.expect(.semicolon, out_err);
        return .{ .return_value = expression };
    }

    fn parseFunction(
        self: *@This(),
        out_err: *ErrorInfo,
    ) Error!ast.Function {
        _ = try self.expect(.int, out_err);
        const name = try self.expect(.ident, out_err);
        _ = try self.expect(.open_paren, out_err);
        _ = try self.expect(.close_paren, out_err);
        _ = try self.expect(.open_brace, out_err);
        const statement = try self.parseStatement(out_err);
        _ = try self.expect(.close_brace, out_err);
        return .{
            .name = name.kind.ident,
            .statement = statement,
        };
    }

    pub fn parse(self: *@This(), out_err: *ErrorInfo) Error!ast.Program {
        return .{ .function = try self.parseFunction(out_err) };
    }
};
