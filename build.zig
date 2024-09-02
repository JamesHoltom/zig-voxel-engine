const std = @import("std");
const builtin = @import("builtin");

const AccessError = std.fs.Dir.AccessError;
const InstallDir = std.Build.InstallDir;

comptime {
    const current_zig = builtin.zig_version;
    const min_zig = std.SemanticVersion.parse("0.13.0") catch unreachable;

    if (current_zig.order(min_zig) == .lt) {
        const error_message = "\n" +
            \\The currently installed version of Zig is {}.
            \\
            \\This project requires a version of {} or higher to compile.
            \\
            \\Please download a development ("master") build from:
            \\
            \\https://ziglang.org/download/
        ;

        @compileError(std.fmt.comptimePrint(error_message, .{ current_zig, min_zig }));
    }
}

// Although this function looks imperative, note that its job is to
// declaratively construct a build graph that will be executed by an external
// runner.
pub fn build(b: *std.Build) void {
    b.verbose = true;
    b.reference_trace = 10;

    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const target = b.standardTargetOptions(.{});

    // Standard optimization options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall. Here we do not
    // set a preferred release mode, allowing the user to decide how to optimize.
    const optimize = b.standardOptimizeOption(.{});

    // This creates a step to generate documentation, visible in the `zig build --help`
    // menu.
    const docs_step = b.step("docs", "Generate documentation");

    // This creates a build step. It will be visible in the `zig build --help` menu,
    // and can be selected like this: `zig build run`
    // This will evaluate the `run` step rather than the default, which is "install".
    const run_step = b.step("run", "Run the app");

    // Similar to creating the run step earlier, this exposes a `test` step to
    // the `zig build --help` menu, providing a way for the user to request
    // running the unit tests.
    const test_step = b.step("test", "Run unit tests");

    const exe = b.addExecutable(.{
        .name = "zve",
        // In this case the main source file is merely a path, however, in more
        // complicated build scripts, this could be a generated file.
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    configureVendorLibraries(exe, target, optimize);

    // This declares intent for the executable to be installed into the
    // standard location when the user invokes the "install" step (the default
    // step when running `zig build`).
    b.installArtifact(exe);

    const docs_source = "docs";
    const generate_exe_docs = b.addInstallDirectory(.{
        .source_dir = exe.getEmittedDocs(),
        .install_dir = .prefix,
        .install_subdir = docs_source,
    });

    // This *creates* a Run step in the build graph, to be executed when another
    // step is evaluated that depends on it. The next line below will establish
    // such a dependency.
    const run_cmd = b.addRunArtifact(exe);

    // By making the run step depend on the install step, it will be run from the
    // installation directory rather than directly from within the cache directory.
    // This is not necessary, however, if the application depends on other installed
    // files, this ensures they will be present and in the expected location.
    run_cmd.step.dependOn(b.getInstallStep());

    // This allows the user to pass arguments to the application in the build
    // command itself, like this: `zig build run -- arg1 arg2 etc`
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    // Creates a step for unit testing the executable. This only builds the test executable but does not run it.
    const exe_unit_tests = b.addTest(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);

    run_step.dependOn(&run_cmd.step);
    docs_step.dependOn(&generate_exe_docs.step);
    test_step.dependOn(&run_exe_unit_tests.step);
}

fn configureVendorLibraries(exe: *std.Build.Step.Compile, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode) void {
    const b = exe.root_module.owner;

    // This includes libC as a dependency.
    exe.linkLibC();

    // This allows us to include the library files in our code.
    exe.addIncludePath(b.path("libs"));

    @import("system_sdk").addLibraryPathsTo(exe);

    // This includes zOpenGL as a dependency.
    const zopengl = b.dependency("zopengl", .{});
    exe.root_module.addImport("zopengl", zopengl.module("root"));

    // This includes zGUI as a dependency.
    const zgui = b.dependency("zgui", .{
        .target = target,
        .backend = .glfw_opengl3,
        .shared = false,
        .with_implot = true,
    });
    exe.root_module.addImport("zgui", zgui.module("root"));
    exe.linkLibrary(zgui.artifact("imgui"));

    // This includes zMath as a dependency.
    const zmath = b.dependency("zmath", .{});
    exe.root_module.addImport("zmath", zmath.module("root"));

    // This includes zGLFW as a dependency.
    const zglfw = b.dependency("zglfw", .{});
    exe.root_module.addImport("zglfw", zglfw.module("root"));
    exe.linkLibrary(zglfw.artifact("glfw"));

    // This includes zPool as a dependency.
    const zpool = b.dependency("zpool", .{});
    exe.root_module.addImport("zpool", zpool.module("root"));

    // This adds string as a dependency.
    const string = b.dependency("string", .{
        .target = target,
        .optimize = optimize,
    });
    exe.root_module.addImport("string", string.module("string"));
}
