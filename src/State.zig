const std = @import("std");
const zopengl = @import("zopengl");
const gl = zopengl.bindings;
const glfw = @import("zglfw");
const gui = @import("zgui");
const callbacks = @import("gl/callbacks.zig");

const StateError = error{
    InitialiseFailed,
};

pub const State = struct {
    window: *glfw.Window,

    pub fn create(allocator: std.mem.Allocator) anyerror!State {
        try glfw.init();

        glfw.windowHintTyped(.context_version_major, 4);
        glfw.windowHintTyped(.context_version_minor, 6);
        glfw.windowHintTyped(.opengl_profile, .opengl_core_profile);
        glfw.windowHintTyped(.opengl_forward_compat, true);
        glfw.windowHintTyped(.client_api, .opengl_api);
        glfw.windowHintTyped(.doublebuffer, true);

        const window = try glfw.Window.create(640, 480, "Test Window", null);

        glfw.makeContextCurrent(window);
        _ = glfw.setErrorCallback(callbacks.glfwErrorCallback);
        _ = window.setFramebufferSizeCallback(callbacks.glfwSizeCallback);

        glfw.swapInterval(1);

        try zopengl.loadCoreProfile(glfw.getProcAddress, 4, 6);

        gl.enable(gl.DEBUG_OUTPUT);
        gl.debugMessageCallback(callbacks.glMessageCallback, null);

        gl.enable(gl.DEPTH_TEST);
        gl.enable(gl.CULL_FACE);
        gl.cullFace(gl.BACK);
        gl.clearColor(0.2, 0.2, 0.2, 1.0);
        gl.viewport(0, 0, 640, 480);

        gui.init(allocator);
        gui.backend.init(window);

        return State{
            .window = window,
        };
    }

    pub fn destroy(self: *@This()) void {
        gui.backend.deinit();
        gui.deinit();
        self.window.destroy();
        glfw.terminate();
    }

    pub fn getAspectRatio(self: @This()) f32 {
        const framebuffer_size = self.window.getFramebufferSize();

        return @as(f32, @floatFromInt(framebuffer_size[0])) / @as(f32, @floatFromInt(framebuffer_size[1]));
    }
};
