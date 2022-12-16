const std = @import("std");
const compile = @import("compile.zig").compile;

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

fn doTest(p: TestPath) !void {
    var a = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer a.deinit();
    const full_path = try std.fs.path.join(a.allocator(), &.{ "src", "tests", p.path });
    std.debug.print("{s} ...\n", .{full_path});
    compile(
        a.allocator(),
        full_path,
        null,
    ) catch |e| {
        if (!p.invalid) return e;
    };
}

pub fn run(stages: usize) !void {
    const a = std.testing.allocator;
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
        try doTest(p);
    }
}
