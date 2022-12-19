const Token = @import("token.zig").Token;

/// The root node of the abstract syntax tree (AST) for a program.
pub const Program = struct {
    /// The main function of the program.
    function: Function,
};

/// A function in the program.
pub const Function = struct {
    /// The name of the function.
    name: []const u8,
    /// The statements comprising the function body.
    statements: []Statement,
};

/// A statement in the function body.
pub const Statement = union(enum) {
    /// A return statement.
    @"return": *Expression,
    /// A declaration of a new variable.
    declare: struct {
        /// The name of the variable being declared.
        name: []const u8,
        /// The initial value of the variable, if provided.
        initializer: ?*Expression,
    },
    /// An expression statement.
    expression: *Expression,
};

/// An enum representing a binary operator.
pub const BinaryOp = enum {
    /// Addition operator (`+`).
    addition,
    /// Subtraction operator (`-`).
    subtraction,
    /// Multiplication operator (`*`).
    multiplication,
    /// Division operator (`/`).
    division,
    /// Logical AND operator (`&&`).
    logical_and,
    /// Logical OR operator (`||`).
    logical_or,
    /// Equal operator (`==`).
    equal,
    /// Not equal operator (`!=`).
    not_equal,
    /// Less than operator (`<`).
    less_than,
    /// Greater than operator (`>`).
    greater_than,
    /// Less than or equal operator (`<=`).
    less_equal,
    /// Greater than or equal operator (`>=`).
    greater_equal,

    /// Get the `BinaryOp` corresponding to a token kind.
    ///
    /// Args:
    /// - tag: The token kind to convert to a `BinaryOp`.
    ///
    /// Returns: The `BinaryOp` corresponding to the given token kind.
    pub fn fromTag(tag: Token.Kind.Tag) @This() {
        return switch (tag) {
            .plus => .addition,
            .minus => .subtraction,
            .star => .multiplication,
            .slash => .division,
            .amp_amp => .logical_and,
            .pipe_pipe => .logical_or,
            .equal_equal => .equal,
            .bang_equal => .not_equal,
            .less => .less_than,
            .greater => .greater_than,
            .less_equal => .less_equal,
            .greater_equal => .greater_equal,
            else => unreachable,
        };
    }
};

/// An enum representing a unary operator.
pub const UnaryOp = enum {
    /// Arithmetic negation operator (`-`).
    arithmetic_negation,
    /// Bitwise negation operator (`~`).
    bitwise_negation,
    /// Logical negation operator (`!`).
    logical_negation,

    /// Get the `UnaryOp` corresponding to a token kind.
    ///
    /// Args:
    /// - tag: The token kind to convert to a `UnaryOp`.
    ///
    /// Returns: The `UnaryOp` corresponding to the given token kind.
    pub fn fromTag(tag: Token.Kind.Tag) @This() {
        return switch (tag) {
            .minus => .arithmetic_negation,
            .tilde => .bitwise_negation,
            .bang => .logical_negation,
            else => unreachable,
        };
    }
};

/// A union representing an expression in the abstract syntax tree (AST).
pub const Expression = union(enum) {
    /// A constant value.
    constant: i32,
    /// A unary operator and its operand.
    unary_op: struct {
        /// The unary operator.
        operator: UnaryOp,
        /// The operand.
        expression: *Expression,
    },
    /// A binary operator, its left operand, and its right operand.
    binary_op: struct {
        /// The left operand.
        left: *Expression,
        /// The binary operator.
        operator: BinaryOp,
        /// The right operand.
        right: *Expression,
    },
    /// An assignment of a value to a variable.
    assign: struct {
        /// The name of the variable.
        name: []const u8,
        /// The value to assign to the variable.
        value: *Expression,
    },
    /// A reference to a variable.
    @"var": []const u8,
};
