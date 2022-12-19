const std = @import("std");
const ast = @import("ast.zig");

const SymbolTable = std.StringHashMap(isize);

/// Struct for generating RISC-V assembly code from an abstract syntax tree (AST).
///
/// Fields:
/// - program: AST of the program being generated.
/// - out_file: File to output the generated assembly code to.
/// - buf: Buffered writer for improved performance when writing to the output file.
pub const CodeGenerator = struct {
    program: ast.Program,
    out_file: std.fs.File,
    buf: std.io.BufferedWriter(4096, std.fs.File.Writer),
    symbols: SymbolTable,
    stack_index: isize,

    /// Initialize a `CodeGenerator` with the given `program` AST and output file at `out_path`.
    ///
    /// Args:
    /// - a: Allocator to use for creating the symbol table.
    /// - program: AST of the program to generate assembly code for.
    /// - out_path: Path to the output file for the generated assembly code.
    pub fn init(
        a: std.mem.Allocator,
        program: ast.Program,
        out_path: []const u8,
    ) !@This() {
        var result: @This() = undefined;
        result.program = program;
        result.out_file = try std.fs.cwd().createFile(out_path, .{});
        result.buf = std.io.bufferedWriter(result.out_file.writer());
        result.symbols = SymbolTable.init(a);
        result.stack_index = 0;
        return result;
    }

    /// Clean up resources used by the `CodeGenerator`.
    ///
    /// Args:
    /// - self: Pointer to the `CodeGenerator` to clean up.
    pub fn deinit(self: *@This()) void {
        self.buf.flush() catch {};
        self.out_file.close();
        self.symbols.deinit();
    }

    /// Write assembly code to set up the global entry point for the program.
    ///
    /// Args:
    /// - w: Output to write the assembly code to.
    fn entryPoint(w: anytype) !void {
        try w.writeAll(".section .text\n");
        try w.writeAll(".global _start\n");
        try w.writeAll("_start:\n");
    }

    /// Write assembly code for the prologue of a RISC-V function.
    ///
    /// Args:
    /// - w: Output to write the assembly code to.
    fn prologue(w: anytype) !void {
        try w.writeAll("addi sp, sp, -8\n");
        try w.writeAll("sw s0, 0(sp)\n");
        try w.writeAll("addi s0, sp, 8\n");
    }

    /// Write assembly code for the epilogue of a RISC-V function.
    ///
    /// Args:
    /// - w: Output to write the assembly code to.
    fn epilogue(w: anytype) !void {
        try w.writeAll("addi sp, s0, 0\n");
        try w.writeAll("lw s0, 0(sp)\n");
        try w.writeAll("addi sp, sp, 8\n");
        try w.writeAll("jalr zero, 0(ra)\n");
    }

    /// Write assembly code to load a constant integer value into a register.
    ///
    /// Args:
    /// - w: Output to write the assembly code to.
    /// - reg: Name of the register to load the constant value into.
    /// - constant: Constant integer value to load into the register.
    fn loadConst(w: anytype, reg: []const u8, constant: anytype) !void {
        comptime std.debug.assert(blk: {
            switch (@typeInfo(@TypeOf(constant))) {
                .Int, .ComptimeInt => break :blk true,
                else => break :blk false,
            }
        });
        try w.print("addi {s}, zero, {d}\n", .{ reg, constant });
    }

    /// Write assembly code to perform a system call with the given number.
    ///
    /// Args:
    /// - w: Output to write the assembly code to.
    /// - number: Integer number of the system call to perform.
    fn syscall(w: anytype, number: anytype) !void {
        comptime std.debug.assert(blk: {
            switch (@typeInfo(@TypeOf(number))) {
                .Int, .ComptimeInt => break :blk true,
                else => break :blk false,
            }
        });
        try loadConst(w, "a7", number);
        try w.writeAll("ecall\n");
    }

    /// Write assembly code to "push" a value onto the stack.
    ///
    /// Args:
    /// - w: Output to write the assembly code to.
    /// - reg: Name of the register containing the value to push onto the stack.
    fn push(w: anytype, reg: []const u8) !void {
        try w.writeAll("addi sp, sp, -8\n");
        try w.print("sd {s}, 8(sp)\n", .{reg});
    }

    /// Write assembly code to "push" a constant integer value onto the stack.
    ///
    /// Args:
    /// - w: Output to write the assembly code to.
    /// - reg: Name of the register to use for loading the constant value.
    /// - constant: Constant integer value to push onto the stack.
    fn pushConst(w: anytype, reg: []const u8, constant: anytype) !void {
        comptime std.debug.assert(blk: {
            switch (@typeInfo(@TypeOf(constant))) {
                .Int, .ComptimeInt => break :blk true,
                else => break :blk false,
            }
        });
        try w.print("addi {s}, zero, {d}\n", .{ reg, constant });
        try push(w, reg);
    }

    /// Write assembly code to "pop" a value off the stack.
    ///
    /// Args:
    /// - w: Output to write the assembly code to.
    /// - reg: Name of the register to store the popped value in.
    fn pop(w: anytype, reg: []const u8) !void {
        try w.writeAll("addi sp, sp, 8\n");
        try w.print("ld {s}, (sp)\n", .{reg});
    }

    /// Write assembly code to perform a bitwise negation on the top value of the stack.
    ///
    /// Args:
    /// - w: Output to write the assembly code to.
    ///
    /// Rough implementation (C):
    /// ```
    /// *top = ~*top;
    /// ```
    fn bitwiseNegate(w: anytype) !void {
        try pop(w, "a0");
        try w.writeAll("xori a0, a0, -1\n");
        try push(w, "a0");
    }

    /// Write assembly code to perform an arithmetic negation on the top value of the stack.
    ///
    /// Args:
    /// - w: Output to write the assembly code to.
    ///
    /// Rough implementation (C):
    /// ```
    /// *top = -*top;
    /// ```
    fn arithmeticNegate(w: anytype) !void {
        try pop(w, "a0");
        try w.writeAll("sub a0, x0, a0\n");
        try push(w, "a0");
    }

    /// Write assembly code to perform a logical negation on the top value of the stack.
    ///
    /// Args:
    /// - w: Output to write the assembly code to.
    ///
    /// Rough implementation (C):
    /// ```
    /// *top = !*top;
    /// ```
    fn logicalNegate(w: anytype) !void {
        try pop(w, "a0");
        try w.writeAll("sltiu a0, a0, 1\n");
        try push(w, "a0");
    }

    /// Write assembly code to perform an addition on the top two values of the stack.
    ///
    /// Args:
    /// - w: Output to write the assembly code to.
    ///
    /// Rough implementation (C):
    /// ```
    /// *(top - 1) = *(top - 1) + *top;
    /// top--;
    /// ```
    fn add(w: anytype) !void {
        try pop(w, "a1");
        try pop(w, "a0");
        try w.writeAll("add a0, a0, a1\n");
        try push(w, "a0");
    }

    /// Write assembly code to perform a subtraction on the top two values of the stack.
    ///
    /// Args:
    /// - w: Output to write the assembly code to.
    ///
    /// Rough implementation (C):
    /// ```
    /// *(top - 1) = *(top - 1) - *top;
    /// top--;
    /// ```
    fn subtract(w: anytype) !void {
        try pop(w, "a1");
        try pop(w, "a0");
        try w.writeAll("sub a0, a0, a1\n");
        try push(w, "a0");
    }

    /// Write assembly code to perform a multiplication on the top two values of the stack.
    ///
    /// Args:
    /// - w: Output to write the assembly code to.
    ///
    /// Rough implementation (C):
    /// ```
    /// *(top - 1) = *(top - 1) * *top;
    /// top--;
    /// ```
    fn multiply(w: anytype) !void {
        try pop(w, "a1");
        try pop(w, "a0");
        try w.writeAll("mul a0, a0, a1\n");
        try push(w, "a0");
    }

    /// Write assembly code to perform a division on the top two values of the stack.
    ///
    /// Args:
    /// - w: Output to write the assembly code to.
    ///
    /// Rough implementation (C):
    /// ```
    /// *(top - 1) = *(top - 1) / *top;
    /// top--;
    /// ```
    fn divide(w: anytype) !void {
        try pop(w, "a1");
        try pop(w, "a0");
        try w.writeAll("divw a0, a0, a1\n");
        try push(w, "a0");
    }

    /// Write assembly code to perform a bitwise AND operation on the top two
    /// values of the stack.
    ///
    /// Args:
    /// - w: Output to write the assembly code to.
    ///
    /// Rough implementation (C):
    /// ```
    /// *(top - 1) = *(top - 1) & *top;
    /// top--;
    /// ```
    fn @"and"(w: anytype) !void {
        try pop(w, "a1");
        try pop(w, "a0");
        try w.writeAll("and a0, a0, a1\n");
        try push(w, "a0");
    }

    /// Write assembly code to perform a bitwise OR operation on the top two values
    /// of the stack.
    ///
    /// Args:
    /// - w: Output to write the assembly code to.
    ///
    /// Rough implementation (C):
    /// ```
    /// *(top - 1) = *(top - 1) | *top;
    /// top--;
    /// ```
    fn @"or"(w: anytype) !void {
        try pop(w, "a1");
        try pop(w, "a0");
        try w.writeAll("or a0, a0, a1\n");
        try push(w, "a0");
    }

    /// Write assembly code to compare the top two values of the stack for equality.
    ///
    /// Args:
    /// - w: Output to write the assembly code to.
    ///
    /// Rough implementation (C):
    /// ```
    /// *(top - 1) = *(top - 1) == *top;
    /// top--;
    /// ```
    fn equal(w: anytype) !void {
        try pop(w, "a1");
        try pop(w, "a0");
        try w.writeAll("xor a0, a0, a1\n");
        try w.writeAll("sltu a0, zero, a0\n");
        try w.writeAll("xori a0, a0, 1\n");
        try push(w, "a0");
    }

    /// Write assembly code to compare the top two values of the stack for inequality.
    ///
    /// Args:
    /// - w: Output to write the assembly code to.
    ///
    /// Rough implementation (C):
    /// ```
    /// *(top - 1) = *(top - 1) != *top;
    /// top--;
    /// ```
    fn notEqual(w: anytype) !void {
        try pop(w, "a1");
        try pop(w, "a0");
        try w.writeAll("xor a0, a0, a1\n");
        try w.writeAll("sltu a0, zero, a0\n");
        try push(w, "a0");
    }

    /// Write assembly code to compare the top two values of the stack for less than.
    ///
    /// Args:
    /// - w: Output to write the assembly code to.
    ///
    /// Rough implementation (C):
    /// ```
    /// *(top - 1) = *(top - 1) < *top;
    /// top--;
    /// ```
    fn less(w: anytype) !void {
        try pop(w, "a1");
        try pop(w, "a0");
        try w.writeAll("slt a0, a0, a1\n");
        try push(w, "a0");
    }

    /// Write assembly code to compare the top two values of the stack for less than
    /// or equal to.
    ///
    /// Args:
    /// - w: Output to write the assembly code to.
    ///
    /// Rough implementation (C):
    /// ```
    /// *(top - 1) = *(top - 1) <= *top;
    /// top--;
    /// ```
    fn lessEqual(w: anytype) !void {
        try pop(w, "a1");
        try pop(w, "a0");
        try w.writeAll("slt a0, a1, a0\n");
        try w.writeAll("xor a0, a0, 1\n");
        try push(w, "a0");
    }

    /// Compare the top two values of the stack for greater than.
    ///
    /// Args:
    /// - w: Output to write the assembly code to.
    ///
    /// Rough implementation (C):
    /// ```
    /// *(top - 1) = *(top - 1) > *top;
    /// top--;
    /// ```
    fn greater(w: anytype) !void {
        try pop(w, "a1");
        try pop(w, "a0");
        try w.writeAll("slt a0, a1, a0\n");
        try push(w, "a0");
    }

    /// Compare the top two values of the stack for greater than or equal to.
    ///
    /// Args:
    /// - w: Output to write the assembly code to.
    ///
    /// Rough implementation (C):
    /// ```
    /// *(top - 1) = *(top - 1) >= *top;
    /// top--;
    /// ```
    fn greaterEqual(w: anytype) !void {
        try pop(w, "a1");
        try pop(w, "a0");
        try w.writeAll("slt a0, a0, a1\n");
        try w.writeAll("xor a0, a0, 1\n");
        try push(w, "a0");
    }

    /// Push a new stack frame onto the stack.
    ///
    /// Args:
    /// - w: Output to write the assembly code to.
    fn pushStackFrame(w: anytype) !void {
        try w.writeAll("addi sp, sp, -8\n");
        try w.writeAll("sd ra, (sp)\n");
    }

    /// Pop the current stack frame from the stack.
    ///
    /// Args:
    /// - w: Output to write the assembly code to.
    fn popStackFrame(w: anytype) !void {
        try w.writeAll("ld ra, (sp)\n");
        try w.writeAll("addi sp, sp, 8\n");
    }

    /// Generate assembly code for an expression.
    ///
    /// Args:
    /// - self: Pointer to the current instance of the code generator.
    /// - w: Output to write the assembly code to.
    /// - expr: Pointer to the expression to generate code for.
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
                    .equal => try equal(w),
                    .not_equal => try notEqual(w),
                    .less_than => try less(w),
                    .less_equal => try lessEqual(w),
                    .greater_than => try greater(w),
                    .greater_equal => try greaterEqual(w),
                    .logical_and => try @"and"(w),
                    .logical_or => try @"or"(w),
                }
            },
            .assign => |assign| {
                try self.genExpression(w, assign.value);
                try pop(w, "a1");
                const index = self.symbols.get(assign.name) orelse
                    return error.UndefinedSymbol;
                try w.print("sd a1, {d}(s0)\n", .{index});
            },
            .@"var" => |@"var"| {
                const index = self.symbols.get(@"var") orelse
                    return error.UndefinedSymbol;
                try w.print("ld a0, {d}(s0)\n", .{index});
                try push(w, "a0");
            },
        }
    }

    fn genStatement(self: *@This(), w: anytype, stmt: ast.Statement) !void {
        switch (stmt) {
            .@"return" => |ret| {
                try self.genExpression(w, ret);
                try pop(w, "a0");
                try genRet(w);
            },
            .declare => |decl| {
                if (self.symbols.contains(decl.name)) {
                    return error.DuplicateSymbol;
                }
                if (decl.initializer) |i| {
                    try self.genExpression(w, i);
                    try push(w, "a0");
                } else {
                    try pushConst(w, "a0", 0);
                }
                try self.symbols.put(decl.name, self.stack_index);
                self.stack_index -= 8;
            },
            .expression => |exp| {
                try self.genExpression(w, exp);
                try pop(w, "a0");
            },
        }
    }

    fn genLabel(w: anytype, name: []const u8) !void {
        try w.print("{s}:\n", .{name});
    }

    fn genFunction(self: *@This(), w: anytype, function: ast.Function) !void {
        try genLabel(w, function.name);
        try prologue(w);
        for (function.statements) |stmt| {
            try self.genStatement(w, stmt);
        }
        try loadConst(w, "a0", 0);
        try genRet(w);
    }

    fn genCall(w: anytype, funcname: []const u8) !void {
        try w.print("jal {s}\n", .{funcname});
    }

    fn genRet(w: anytype) !void {
        try epilogue(w);
        try w.writeAll("jr ra\n");
    }

    /// Generate assembly code for the program.
    ///
    /// Args:
    /// - self: Pointer to the current instance of the code generator.
    pub fn gen(self: *@This()) !void {
        var w = self.buf.writer();
        try entryPoint(w);
        try genCall(w, "main");
        try syscall(w, 93);
        try self.genFunction(w, self.program.function);
    }
};
