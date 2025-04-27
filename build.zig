const std = @import("std");

// -Drelease for release build
// -Drisky for slighty smaller (but risky) build
// shrink for slighyl smaller output (safe, repends on sstrip from elf-kickers and wc)

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const mod = b.addModule("sudoku_fast", .{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    // build
    const exe = b.addExecutable(.{ .name = "sudoku_fast", .root_module = mod });
    b.installArtifact(exe);

    // optimize
    if (optimize == .ReleaseFast or optimize == .ReleaseSmall) {
        // toggle compiler options for exe
        exe.link_data_sections = true;
        exe.link_function_sections = true;
        // toggle compiler options for mod
        mod.strip = true;
    }

    if (optimize == .ReleaseSmall) {
        exe.bundle_compiler_rt = false;
        exe.no_builtin = true;
        mod.single_threaded = true;
    }

    // run
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| run_cmd.addArgs(args);
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    // tests
    const exe_unit_tests = b.addTest(.{ .root_module = mod });
    const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_exe_unit_tests.step);
}
