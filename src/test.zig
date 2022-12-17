const std = @import("std");
const compiler = @import("compiler.zig");

const TestPath = struct {
    path: []u8,
    num: usize,
    invalid: bool,

    fn init(path: []u8) !@This() {
        const numStart = std.mem.indexOfScalar(u8, path, '_').? + 1;
        const numEnd = std.mem.indexOfScalarPos(
            u8,
            path,
            numStart + 1,
            '/',
        ).?;
        const num = try std.fmt.parseInt(usize, path[numStart..numEnd], 10);
        const maybe_invalid = std.mem.indexOfPos(
            u8,
            path,
            numEnd + 1,
            "invalid",
        );
        const invalid = if (maybe_invalid) |i|
            i == numEnd + 1
        else
            false;
        return .{
            .path = path,
            .num = num,
            .invalid = invalid,
        };
    }
};

fn doTest(p: TestPath, a: std.mem.Allocator) !void {
    var arena = std.heap.ArenaAllocator.init(a);
    defer arena.deinit();
    const aa = arena.allocator();
    const full_path = try std.fs.path.join(aa, &.{ "src", "tests", p.path });
    std.debug.print("{s} ...\n", .{full_path});
    var err: compiler.ErrorInfo = undefined;
    compiler.compile(
        aa,
        full_path,
        null,
        &err,
    ) catch |e| if (!p.invalid) {
        std.debug.print("error: {}\n", .{err});
        return e;
    };
    if (!p.invalid) {
        var child = std.ChildProcess.init(
            &.{ "qemu-riscv64", "a.out" },
            aa,
        );
        const actual_ret = try child.spawnAndWait();

        child = std.ChildProcess.init(&.{
            "zig",
            "cc",
            "-target",
            "riscv64-linux-musl",
            full_path,
        }, aa);
        const compiler_ret = try child.spawnAndWait();
        std.debug.assert(compiler_ret.Exited == 0);

        child = std.ChildProcess.init(&.{
            "qemu-riscv64",
            "a.out",
        }, aa);
        const expected_ret = try child.spawnAndWait();

        try std.testing.expectEqual(expected_ret, actual_ret);

        try std.fs.cwd().deleteFile("a.out");
    }
}

pub fn main() !void {
    run() catch std.process.exit(1);
}

pub fn run() !void {
    const stages = 2;

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.detectLeaks();
    const a = gpa.allocator();
    var dir = try std.fs.cwd().openIterableDir("src/tests", .{});
    var walker = try dir.walk(a);
    defer walker.deinit();

    var arena = std.heap.ArenaAllocator.init(a);
    defer arena.deinit();
    var aa = arena.allocator();
    var paths = std.ArrayList(TestPath).init(aa);

    while (try walker.next()) |ent| {
        if (std.mem.startsWith(u8, ent.path, "stage_") and
            std.mem.endsWith(u8, ent.path, ".c"))
        {
            try paths.append(try TestPath.init(try aa.dupe(u8, ent.path)));
        }
    }

    std.sort.sort(TestPath, paths.items, {}, struct {
        fn lt(_: void, s1: TestPath, s2: TestPath) bool {
            return s1.num < s2.num or
                s1.num == s2.num and std.mem.lessThan(u8, s1.path, s2.path);
        }
    }.lt);
    var stage: usize = 0;
    std.debug.print("\n", .{});
    for (paths.items) |p| {
        if (p.num > stages) break;

        if (p.num != stage) {
            std.debug.print("== STAGE {d} ==\n", .{p.num});
            stage = p.num;
        }
        try doTest(p, a);
    }
}
