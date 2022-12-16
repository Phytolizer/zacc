const std = @import("std");
const Parser = @import("parser.zig").Parser;
const CodeGenerator = @import("codegen.zig").CodeGenerator;

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
    const ast = try parser.parse();
    const temp_dpath = "zacc-temp";
    var temp_dir = try std.fs.cwd().makeOpenPath(temp_dpath, .{});
    defer {
        temp_dir.close();
        std.fs.cwd().deleteTree(temp_dpath) catch {};
    }
    const temp_path = try std.fs.path.join(a, &.{ temp_dpath, "out.s" });
    {
        var cg = try CodeGenerator.init(ast, temp_path);
        defer cg.deinit();
        try cg.gen();
    }
    var child = std.ChildProcess.init(&.{
        "zig",
        "cc",
        "--target=riscv64-linux-musl",
        "-no-pie",
        "-nostdlib",
        "-o",
        output orelse "a.out",
        temp_path,
    }, a);
    const failed = switch (try child.spawnAndWait()) {
        .Exited => |status| status != 0,
        else => true,
    };
    if (failed) return error.Compile;
}
