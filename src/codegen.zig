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
        try w.print("addi {s}, zero, {d}\n", .{ reg, constant });
    }

    fn push(w: anytype, reg: []const u8) !void {
        try w.writeAll("addi sp, sp, -8\n");
        try w.print("sd {s}, 8(sp)\n", .{reg});
    }

    fn pushConst(w: anytype, reg: []const u8, constant: anytype) !void {
        try w.print("addi {s}, zero, {d}\n", .{ reg, constant });
        try push(w, reg);
    }

    fn pop(w: anytype, reg: []const u8) !void {
        try w.writeAll("addi sp, sp, 8\n");
        try w.print("ld {s}, (sp)\n", .{reg});
    }

    fn bitwiseNegate(w: anytype) !void {
        try pop(w, "a0");
        try w.writeAll("xori a0, a0, -1\n");
        try push(w, "a0");
    }

    fn arithmeticNegate(w: anytype) !void {
        try pop(w, "a0");
        try w.writeAll("sub a0, x0, a0\n");
        try push(w, "a0");
    }

    fn logicalNegate(w: anytype) !void {
        try pop(w, "a0");
        try w.writeAll("sltiu a0, a0, 1\n");
        try push(w, "a0");
    }

    fn add(w: anytype) !void {
        try pop(w, "a1");
        try pop(w, "a0");
        try w.writeAll("add a0, a0, a1\n");
        try push(w, "a0");
    }

    fn subtract(w: anytype) !void {
        try pop(w, "a1");
        try pop(w, "a0");
        try w.writeAll("sub a0, a0, a1\n");
        try push(w, "a0");
    }

    fn multiply(w: anytype) !void {
        try pop(w, "a1");
        try pop(w, "a0");
        try w.writeAll("mul a0, a0, a1\n");
        try push(w, "a0");
    }

    fn divide(w: anytype) !void {
        try pop(w, "a1");
        try pop(w, "a0");
        try w.writeAll("divw a0, a0, a1\n");
        try push(w, "a0");
    }

    // RV64I asm
    fn genExpression(self: *@This(), w: anytype, expr: *ast.Expression) !void {
        switch (expr.*) {
            .constant => |v| try pushConst(w, "a1", v),
            .unary_op => |op| {
                try self.genExpression(w, op.expression);
                switch (op.operator) {
                    .bitwise_negation => try bitwiseNegate(w),
                    .arithmetic_negation => try arithmeticNegate(w),
                    .logical_negation => try logicalNegate(w),
                }
            },
            .binary_op => |op| {
                try self.genExpression(w, op.left);
                try self.genExpression(w, op.right);
                switch (op.operator) {
                    .addition => try add(w),
                    .subtraction => try subtract(w),
                    .multiplication => try multiply(w),
                    .division => try divide(w),
                }
            },
        }
    }

    pub fn gen(self: *@This()) !void {
        var w = self.buf.writer();
        try prologue(w);
        const retval = self.program.function.statement.return_value;
        try self.genExpression(w, retval);
        try pop(w, "a0");
        try loadConst(w, "a7", 93);
        try w.writeAll("ecall\n");
    }
};
