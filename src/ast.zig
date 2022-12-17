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
};
