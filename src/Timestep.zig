const glfw = @import("zglfw");

pub const Timestep = struct {
    var last_interval: f64 = 0.0;
    var current_interval: f64 = 0.0;

    pub fn nextFrame() void {
        last_interval = current_interval;
        current_interval = glfw.getTime();
    }

    pub fn get() f64 {
        return current_interval - last_interval;
    }
};
