const std = @import("std");
const glfw = @import("zglfw");

pub const MouseMovement = struct {
    var previous_position: [2]f64 = .{ 0.0, 0.0 };
    var current_position: [2]f64 = .{ 0.0, 0.0 };

    pub fn nextFrame() void {
        previous_position[0] = current_position[0];
        previous_position[1] = current_position[1];
    }

    pub fn getMovement() [2]f64 {
        return .{
            current_position[0] - previous_position[0],
            current_position[1] - previous_position[1],
        };
    }

    pub fn glfwCursorPosCallback(_: *glfw.Window, x_position: f64, y_position: f64) callconv(.C) void {
        current_position[0] = x_position;
        current_position[1] = y_position;
    }
};
