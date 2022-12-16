pub const Program = struct {
    function: Function,
};

pub const Function = struct {
    name: []const u8,
    statement: Statement,
};

pub const Statement = struct {
    return_value: Expression,
};

pub const Expression = struct {
    value: i32,
};
