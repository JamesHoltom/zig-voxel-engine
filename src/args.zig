const std = @import("std");

pub const CLArguments = struct {};

pub fn GetCLArguments(alloc: std.mem.Allocator) !CLArguments {
    const args = try std.process.argsAlloc(alloc);
    defer std.process.argsFree(alloc, args);

    const clArgs: CLArguments = CLArguments{};

    for (args[1..], 0..) |arg, i| {
        std.log.info("{d}: {s}", .{ i, arg });
    }

    return clArgs;
}
