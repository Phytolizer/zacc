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
        filepath: []const u8,
        line: usize,
        column: usize,

        pub fn format(
            self: @This(),
            comptime _: []const u8,
            _: std.fmt.FormatOptions,
            writer: anytype,
        ) !void {
            try writer.print("{s}:{d}:{d}: {s}", .{
                self.filepath,
                self.line,
                self.column,
                self.message,
            });
        }
    };

    pub fn init(
        a: std.mem.Allocator,
        filepath: []const u8,
        out_lex_err: *Lexer.ErrorInfo,
    ) !@This() {
        var result: @This() = undefined;
        result.a = a;
        result.lexer = try Lexer.init(a, filepath);
        result.tokens = try result.lexer.lex(out_lex_err);
        result.pos = 0;
        return result;
    }

    pub fn deinit(self: @This()) void {
        self.lexer.deinit();
    }

    fn current(self: *@This()) Token {
        return self.tokens[self.pos];
    }

    fn peek(self: *@This()) ?Token {
        if (self.pos < self.tokens.len) return self.tokens[self.pos + 1];
        return null;
    }

    fn advance(self: *@This()) Token {
        const result = self.current();
        self.pos += 1;
        return result;
    }

    fn expect(
        self: *@This(),
        kind: Token.Kind.Tag,
        out_err: *ErrorInfo,
    ) Error!Token {
        if (self.current().kind.tag() == kind) {
            return self.advance();
        } else {
            out_err.* = .{
                .message = try std.fmt.allocPrint(
                    self.a,
                    "unexpected token \"{}\", expected <{}>",
                    .{ self.current().kind, kind },
                ),
                .filepath = self.current().filepath,
                .line = self.current().line,
                .column = self.current().column,
            };
            return error.UnexpectedToken;
        }
    }

    fn parseFactor(self: *@This(), out_err: *ErrorInfo) Error!*ast.Expression {
        var result = try self.a.create(ast.Expression);
        switch (self.current().kind.tag()) {
            .open_paren => {
                self.a.destroy(result);
                self.pos += 1;
                result = try self.parseExpression(out_err);
                _ = try self.expect(.close_paren, out_err);
            },
            .bang, .minus, .tilde => {
                const unary_op = ast.UnaryOp.fromTag(self.current().kind.tag());
                self.pos += 1;
                const operand = try self.parseFactor(out_err);
                result.* = .{ .unary_op = .{
                    .operator = unary_op,
                    .expression = operand,
                } };
            },
            .ident => {
                const token = self.advance();
                result.* = .{ .@"var" = token.kind.ident };
            },
            else => {
                const token = try self.expect(.constant, out_err);
                result.* = .{ .constant = token.kind.constant };
            },
        }
        return result;
    }

    fn parseTerm(self: *@This(), out_err: *ErrorInfo) Error!*ast.Expression {
        var result = try self.parseFactor(out_err);
        while (true) {
            switch (self.current().kind.tag()) {
                .star, .slash => {
                    const left = result;
                    const operator =
                        ast.BinaryOp.fromTag(self.current().kind.tag());
                    self.pos += 1;
                    const right = try self.parseFactor(out_err);
                    result = try self.a.create(ast.Expression);
                    result.* = .{ .binary_op = .{
                        .left = left,
                        .operator = operator,
                        .right = right,
                    } };
                },
                else => break,
            }
        }
        return result;
    }

    fn parseAdditiveExpression(
        self: *@This(),
        out_err: *ErrorInfo,
    ) Error!*ast.Expression {
        var result = try self.parseTerm(out_err);
        while (true) {
            switch (self.current().kind.tag()) {
                .plus, .minus => {
                    const left = result;
                    const operator =
                        ast.BinaryOp.fromTag(self.current().kind.tag());
                    self.pos += 1;
                    const right = try self.parseTerm(out_err);
                    result = try self.a.create(ast.Expression);
                    result.* = .{ .binary_op = .{
                        .left = left,
                        .operator = operator,
                        .right = right,
                    } };
                },
                else => break,
            }
        }
        return result;
    }

    fn parseRelationalExpression(
        self: *@This(),
        out_err: *ErrorInfo,
    ) Error!*ast.Expression {
        var result = try self.parseAdditiveExpression(out_err);
        while (true) {
            switch (self.current().kind.tag()) {
                .less, .greater, .less_equal, .greater_equal => {
                    const left = result;
                    const operator =
                        ast.BinaryOp.fromTag(self.current().kind.tag());
                    self.pos += 1;
                    const right = try self.parseAdditiveExpression(out_err);
                    result = try self.a.create(ast.Expression);
                    result.* = .{ .binary_op = .{
                        .left = left,
                        .operator = operator,
                        .right = right,
                    } };
                },
                else => break,
            }
        }
        return result;
    }

    fn parseEqualityExpression(
        self: *@This(),
        out_err: *ErrorInfo,
    ) Error!*ast.Expression {
        var result = try self.parseRelationalExpression(out_err);
        while (true) {
            switch (self.current().kind.tag()) {
                .equal_equal, .bang_equal => {
                    const left = result;
                    const operator =
                        ast.BinaryOp.fromTag(self.current().kind.tag());
                    self.pos += 1;
                    const right = try self.parseRelationalExpression(out_err);
                    result = try self.a.create(ast.Expression);
                    result.* = .{ .binary_op = .{
                        .left = left,
                        .operator = operator,
                        .right = right,
                    } };
                },
                else => break,
            }
        }
        return result;
    }

    fn parseLogicalAndExpression(
        self: *@This(),
        out_err: *ErrorInfo,
    ) Error!*ast.Expression {
        var result = try self.parseEqualityExpression(out_err);
        while (true) {
            switch (self.current().kind.tag()) {
                .amp_amp => {
                    const left = result;
                    const operator =
                        ast.BinaryOp.fromTag(self.current().kind.tag());
                    self.pos += 1;
                    const right = try self.parseEqualityExpression(out_err);
                    result = try self.a.create(ast.Expression);
                    result.* = .{ .binary_op = .{
                        .left = left,
                        .operator = operator,
                        .right = right,
                    } };
                },
                else => break,
            }
        }
        return result;
    }

    fn parseLogicalOrExpression(
        self: *@This(),
        out_err: *ErrorInfo,
    ) Error!*ast.Expression {
        var result = try self.parseLogicalAndExpression(out_err);
        while (true) {
            switch (self.current().kind.tag()) {
                .pipe_pipe => {
                    const left = result;
                    const operator =
                        ast.BinaryOp.fromTag(self.current().kind.tag());
                    self.pos += 1;
                    const right = try self.parseLogicalAndExpression(out_err);
                    result = try self.a.create(ast.Expression);
                    result.* = .{ .binary_op = .{
                        .left = left,
                        .operator = operator,
                        .right = right,
                    } };
                },
                else => break,
            }
        }
        return result;
    }

    fn parseAssignmentExpression(
        self: *@This(),
        out_err: *ErrorInfo,
    ) Error!*ast.Expression {
        if (self.current().kind.tag() == .ident) {
            const pt = self.peek();
            if (pt != null and pt.?.kind.tag() == .equal) {
                const name = self.advance();
                self.pos += 1;
                const expression =
                    try self.parseAssignmentExpression(out_err);
                const result = try self.a.create(ast.Expression);
                result.* = .{ .assign = .{
                    .name = name.kind.ident,
                    .value = expression,
                } };
                return result;
            }
        }

        return try self.parseLogicalOrExpression(out_err);
    }

    fn parseExpression(self: *@This(), out_err: *ErrorInfo) Error!*ast.Expression {
        return try self.parseAssignmentExpression(out_err);
    }

    fn parseStatement(
        self: *@This(),
        out_err: *ErrorInfo,
    ) Error!ast.Statement {
        switch (self.current().kind.tag()) {
            .@"return" => {
                self.pos += 1;
                const expression = try self.parseExpression(out_err);
                _ = try self.expect(.semicolon, out_err);
                return .{ .@"return" = expression };
            },
            .int => {
                self.pos += 1;
                const name = try self.expect(.ident, out_err);
                var initializer: ?*ast.Expression = null;
                if (self.current().kind.tag() == .equal) {
                    self.pos += 1;
                    initializer = try self.parseExpression(out_err);
                }
                _ = try self.expect(.semicolon, out_err);
                return .{ .declare = .{
                    .name = name.kind.ident,
                    .initializer = initializer,
                } };
            },
            else => {
                const expression = try self.parseExpression(out_err);
                _ = try self.expect(.semicolon, out_err);
                return .{ .expression = expression };
            },
        }
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
        var statements = std.ArrayList(ast.Statement).init(self.a);
        while (self.current().kind.tag() != .close_brace) {
            const statement = try self.parseStatement(out_err);
            try statements.append(statement);
        }
        _ = try self.expect(.close_brace, out_err);
        return .{
            .name = name.kind.ident,
            .statements = try statements.toOwnedSlice(),
        };
    }

    pub fn parse(self: *@This(), out_err: *ErrorInfo) Error!ast.Program {
        return .{ .function = try self.parseFunction(out_err) };
    }
};
