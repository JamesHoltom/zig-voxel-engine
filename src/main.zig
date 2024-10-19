const Application = @import("Application.zig").Application;

/// Main entrypoint.
pub fn main() !void {
    try Application.run();
}
