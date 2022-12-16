const std = @import("std");
const Parser = @import("parser.zig").Parser;

pub fn compile(
    a: std.mem.Allocator,
    input: []const u8,
    output: ?[]const u8,
) !void {
    const contents = try std.fs.cwd().readFileAlloc(
        a,
        input,
        std.math.maxInt(usize),
    );
    var parser = try Parser.init(a, contents);
    _ = try parser.parse();
    _ = output;
}
