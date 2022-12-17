const std = @import("std");

pub fn build(b: *std.build.Builder) void {
    const target = b.standardTargetOptions(.{});
    const mode = b.standardReleaseOptions();

    const exe = b.addExecutable("zacc", "src/main.zig");
    exe.setTarget(target);
    exe.setBuildMode(mode);
    exe.install();

    const run_cmd = exe.run();
    run_cmd.step.dependOn(b.getInstallStep());
    run_cmd.expected_exit_code = null;
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const exe_tests = b.addExecutable("zacc-test", "src/test.zig");
    exe_tests.setTarget(target);
    exe_tests.setBuildMode(mode);

    const exe_tests_run_cmd = exe_tests.run();
    exe_tests_run_cmd.expected_exit_code = null;

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&exe_tests_run_cmd.step);
}
