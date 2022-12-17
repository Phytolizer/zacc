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

    fn prologue(w: anytype) !void {
        try w.writeAll(".section .text\n");
        try w.writeAll(".global _start\n");
        try w.writeAll("_start:\n");
    }

    fn loadConst(w: anytype, reg: []const u8, constant: anytype) !void {
        try w.print("xor {s}, {s}, {s}\n", .{ reg, reg, reg });
        try w.print("addi {s}, {s}, {d}\n", .{ reg, reg, constant });
    }

    fn bitwiseNegate(w: anytype) !void {
        try w.writeAll("xori a0, a0, -1\n");
    }

    fn arithmeticNegate(w: anytype) !void {
        try w.writeAll("sub a0, x0, a0\n");
    }

    fn logicalNegate(w: anytype) !void {
        try w.writeAll("sltiu a0, a0, 1\n");
    }

    // RV64I asm
    fn genExpression(self: *@This(), w: anytype, expr: *ast.Expression) !void {
        switch (expr.*) {
            .constant => |v| try loadConst(w, "a0", v),
            .unary_op => |op| {
                try self.genExpression(w, op.expression);
                switch (op.operator) {
                    .bitwise_negation => try bitwiseNegate(w),
                    .arithmetic_negation => try arithmeticNegate(w),
                    .logical_negation => try logicalNegate(w),
                }
            },
        }
    }

    pub fn gen(self: *@This()) !void {
        var w = self.buf.writer();
        try prologue(w);
        const retval = self.program.function.statement.return_value;
        try self.genExpression(w, retval);
        try loadConst(w, "a7", 93);
        try w.writeAll("ecall\n");
    }
};
