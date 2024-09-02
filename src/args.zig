const std = @import("std");

pub const CLArguments = struct {};

pub fn GetCLArguments() !CLArguments {
    const args = try std.process.argsAlloc(std.heap.page_allocator);
    defer std.process.argsFree(std.heap.page_allocator, args);

    const clArgs: CLArguments = CLArguments{};

    for (args[1..], 0..) |arg, i| {
        std.log.info("{d}: {s}", .{ i, arg });
    }

    return clArgs;
}
