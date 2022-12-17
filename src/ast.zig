const Token = @import("token.zig").Token;

pub const Program = struct {
    function: Function,
};

pub const Function = struct {
    name: []const u8,
    statement: Statement,
};

pub const Statement = struct {
    return_value: *Expression,
};

pub const BinaryOp = enum {
    addition,
    subtraction,
    multiplication,
    division,
    logical_and,
    logical_or,
    equal,
    not_equal,
    less_than,
    greater_than,
    less_equal,
    greater_equal,

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

pub const UnaryOp = enum {
    arithmetic_negation,
    bitwise_negation,
    logical_negation,

    pub fn fromTag(tag: Token.Kind.Tag) @This() {
        return switch (tag) {
            .minus => .arithmetic_negation,
            .tilde => .bitwise_negation,
            .bang => .logical_negation,
            else => unreachable,
        };
    }
};

pub const Expression = union(enum) {
    constant: i32,
    unary_op: struct {
        operator: UnaryOp,
        expression: *Expression,
    },
    binary_op: struct {
        left: *Expression,
        operator: BinaryOp,
        right: *Expression,
    },
};
