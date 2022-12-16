const std = @import("std");
const Lexer = @import("lexer.zig").Lexer;

pub fn compile(
    a: std.mem.Allocator,
    input: []const u8,
    output: ?[]const u8,
) !void {
    const contents = try std.fs.cwd().readFileAlloc(
        a,
        input,
        std.math.maxInt(usize),
    );
    var lexer = Lexer.init(a, contents);
    defer lexer.deinit();
    _ = try lexer.lex();
    _ = output;
}
