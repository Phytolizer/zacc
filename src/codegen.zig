const std = @import("std");
const Program = @import("ast.zig").Program;

pub const CodeGenerator = struct {
    ast: Program,
    out_file: std.fs.File,
    buf: std.io.BufferedWriter(4096, std.fs.File.Writer),

    pub fn init(
        ast: Program,
        out_path: []const u8,
    ) !@This() {
        var result: @This() = undefined;
        result.ast = ast;
        result.out_file = try std.fs.cwd().createFile(out_path, .{});
        result.buf = std.io.bufferedWriter(result.out_file.writer());
        return result;
    }

    pub fn deinit(self: *@This()) void {
        self.buf.flush() catch {};
        self.out_file.close();
    }

    pub fn gen(self: *@This()) !void {
        // ARMv6-M asm
        var w = self.buf.writer();
        try w.print(
            "mov r0, #{d}\n",
            .{self.ast.function.statement.return_value.value},
        );
        try w.print("svc #1\n", .{});
    }
};
