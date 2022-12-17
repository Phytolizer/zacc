const std = @import("std");
const ast = @import("ast.zig");

pub const CodeGenerator = struct {
    program: ast.Program,
    out_file: std.fs.File,
    buf: std.io.BufferedWriter(4096, std.fs.File.Writer),

    pub fn init(
        program: ast.Program,
        out_path: []const u8,
    ) !@This() {
        var result: @This() = undefined;
        result.program = program;
        result.out_file = try std.fs.cwd().createFile(out_path, .{});
        result.buf = std.io.bufferedWriter(result.out_file.writer());
        return result;
    }

    pub fn deinit(self: *@This()) void {
        self.buf.flush() catch {};
        self.out_file.close();
    }

    // RV64I asm
    fn genExpression(self: *@This(), w: anytype, expr: *ast.Expression) !void {
        switch (expr.*) {
            .constant => |v| {
                try w.print("xor a0, a0, a0\n", .{});
                try w.print("addi a0, a0, {d}\n", .{v});
            },
            .unary_op => |op| {
                try self.genExpression(w, op.expression);
                switch (op.operator) {
                    .bitwise_negation => try w.print("xori a0, a0, -1\n", .{}),
                    .arithmetic_negation => try w.print("sub a0, x0, a0\n", .{}),
                    .logical_negation => try w.print("sltiu a0, a0, 1\n", .{}),
                }
            },
        }
    }

    pub fn gen(self: *@This()) !void {
        var w = self.buf.writer();
        try w.writeAll(".section .text\n");
        try w.writeAll(".global _start\n");
        try w.writeAll("_start:\n");
        const retval = self.program.function.statement.return_value;
        try self.genExpression(w, retval);
        try w.print("xor a7, a7, a7\n", .{});
        try w.print("addi a7, a7, 93\n", .{});
        try w.writeAll("ecall\n");
    }
};
