const std = @import("std");
const compiler = @import("compiler.zig");

pub fn main() !void {
    run() catch std.process.exit(1);
}

pub fn run() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.detectLeaks();
    var arena = std.heap.ArenaAllocator.init(gpa.allocator());
    defer arena.deinit();
    const aa = arena.allocator();

    const args = try std.process.argsAlloc(aa);

    var err: compiler.ErrorInfo = undefined;
    compiler.compile(
        aa,
        args[1],
        null,
        &err,
    ) catch |e| {
        std.debug.print("error: {}\n", .{err});
        return e;
    };
}
