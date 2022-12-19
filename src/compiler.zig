const std = @import("std");
const Lexer = @import("lexer.zig").Lexer;
const Parser = @import("parser.zig").Parser;
const CodeGenerator = @import("codegen.zig").CodeGenerator;

/// An error encountered during compilation.
pub const ErrorInfo = union(enum) {
    parse: Parser.ErrorInfo,
    lex: Lexer.ErrorInfo,

    /// Format the error information for printing.
    ///
    /// Args:
    /// - self: The current instance of the error information.
    /// - _: Unused.
    /// - _: Unused.
    /// - writer: Output to write the formatted error information to.
    pub fn format(
        self: @This(),
        comptime _: []const u8,
        _: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        switch (self) {
            .parse => |e| try writer.print("{}", .{e}),
            .lex => |e| try writer.print("{}", .{e}),
        }
    }
};

/// Compile a program from source code.
///
/// Args:
/// - a: Memory allocator to use for temporary buffers.
/// - input: The source code to compile.
/// - output: The path to write the compiled executable to. If not provided, the
///   executable will be written to "a.out".
/// - out_err: Pointer to a variable to store error information in case of failure.
pub fn compile(
    a: std.mem.Allocator,
    input: []const u8,
    output: ?[]const u8,
    out_err: *ErrorInfo,
) !void {
    var lex_err: Lexer.ErrorInfo = undefined;
    var parser = Parser.init(a, input, &lex_err) catch |e| {
        out_err.* = .{ .lex = lex_err };
        return e;
    };
    var parse_err: Parser.ErrorInfo = undefined;
    const ast = parser.parse(&parse_err) catch |e| {
        out_err.* = .{ .parse = parse_err };
        return e;
    };
    const temp_dpath = "zacc-temp";
    var temp_dir = try std.fs.cwd().makeOpenPath(temp_dpath, .{});
    defer {
        temp_dir.close();
        // std.fs.cwd().deleteTree(temp_dpath) catch {};
    }
    const temp_path = try std.fs.path.join(a, &.{ temp_dpath, "out.s" });
    {
        var cg = try CodeGenerator.init(a, ast, temp_path);
        defer cg.deinit();
        try cg.gen();
    }
    var child = std.ChildProcess.init(&.{
        "zig",
        "cc",
        "--target=riscv64-linux-musl",
        "-no-pie",
        "-nostdlib",
        "-o",
        output orelse "a.out",
        temp_path,
    }, a);
    const failed = switch (try child.spawnAndWait()) {
        .Exited => |status| status != 0,
        else => true,
    };
    if (failed) return error.Compile;
}
