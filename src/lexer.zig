const std = @import("std");
const Token = @import("token.zig").Token;

pub const Lexer = struct {
    arena: std.heap.ArenaAllocator,
    input: []const u8,
    filepath: []const u8,
    offset: usize = 0,
    line: usize = 1,
    column: usize = 1,

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

    pub fn init(a: std.mem.Allocator, filepath: []const u8) !@This() {
        const input = try std.fs.cwd().readFileAlloc(
            a,
            filepath,
            std.math.maxInt(usize),
        );
        var result = @This(){
            .arena = std.heap.ArenaAllocator.init(a),
            .input = input,
            .filepath = filepath,
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
            if (c == '\n') {
                self.line += 1;
                self.column = 0;
            }
            self.column += 1;
        }
        self.offset += 1;
    }

    fn nextToken(self: *@This(), out_err: *ErrorInfo) !Token.Kind {
        const start = self.offset;
        const start_line = self.line;
        const start_column = self.column;
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
                    if (self.get()) |c2| if (c2 == '=') {
                        self.next();
                        return .bang_equal;
                    };

                    return .bang;
                },
                '=' => {
                    self.next();
                    if (self.get()) |c2| if (c2 == '=') {
                        self.next();
                        return .equal_equal;
                    };

                    return .equal;
                },
                '&' => {
                    self.next();
                    if (self.get()) |c2| if (c2 == '&') {
                        self.next();
                        return .amp_amp;
                    };
                },
                '|' => {
                    self.next();
                    if (self.get()) |c2| if (c2 == '|') {
                        self.next();
                        return .pipe_pipe;
                    };
                },
                '<' => {
                    self.next();
                    if (self.get()) |c2| if (c2 == '=') {
                        self.next();
                        return .less_equal;
                    };
                    return .less;
                },
                '>' => {
                    self.next();
                    if (self.get()) |c2| if (c2 == '=') {
                        self.next();
                        return .greater_equal;
                    };
                    return .greater;
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
                    const id_start = self.offset;
                    while (self.get()) |c2| {
                        if (!std.ascii.isAlphanumeric(c2) and c2 != '_') break;
                        self.next();
                    }
                    const keywords = std.ComptimeStringMap(Token.Kind, .{
                        .{ "int", .int },
                        .{ "return", .@"return" },
                    });
                    const text = self.input[id_start..self.offset];
                    return keywords.get(text) orelse
                        .{ .ident = try self.arena.allocator().dupe(u8, text) };
                } else if (std.ascii.isDigit(c)) {
                    const num_start = self.offset;
                    while (self.get()) |c2| {
                        if (!std.ascii.isDigit(c2)) break;
                        self.next();
                    }
                    const text = self.input[num_start..self.offset];
                    const num = try std.fmt.parseInt(i32, text, 10);
                    return .{ .constant = num };
                } else self.next(),
            }
            out_err.* = .{
                .message = std.fmt.allocPrint(
                    self.arena.allocator(),
                    "unrecognized token: {s}",
                    .{self.input[start..self.offset]},
                ) catch unreachable,
                .filepath = self.filepath,
                .line = start_line,
                .column = start_column,
            };
            return error.UnrecognizedToken;
        } else return .eof;
    }

    pub fn lex(self: *@This(), out_err: *ErrorInfo) ![]Token {
        var tokens = std.ArrayList(Token).init(self.arena.allocator());
        while (true) {
            while (self.get()) |c| {
                if (!std.ascii.isWhitespace(c)) break;
                self.next();
            }
            const line = self.line;
            const column = self.column;
            const token_kind = try self.nextToken(out_err);
            const token = Token.init(token_kind, self.filepath, line, column);
            try tokens.append(token);

            if (token.kind == .eof) break;
        }
        return try tokens.toOwnedSlice();
    }
};
