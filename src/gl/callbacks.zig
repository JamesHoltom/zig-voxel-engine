const std = @import("std");
const gl = @import("zopengl").bindings;
const glfw = @import("zglfw");

/// __Parameters__:
/// * _source_: The source of the message.
/// * _message_type_: The type of message.
/// * _id_: The ID of the message.
/// * _severity_: The severity of the message.
/// * _message_: The message string.
pub fn glMessageCallback(
    source: c_uint,
    message_type: c_uint,
    id: c_uint,
    severity: c_uint,
    _: c_int,
    message: [*c]const u8,
    _: *const anyopaque,
) callconv(.C) void {
    if (id == 131169 or // Notification that GL has allocated storage for a render buffer.
        id == 131185 or // NVIDIA-specific notification stating that because a buffer is configured for static drawing (i.e. using the "GL_STATIC_DRAW" flag), it will be stored in video memory, rather than system memory.
        id == 131204 or // Warning that a texture does not have a base level defined, and can't be used for texture mapping.
        id == 131218) // Warning that a shader is being recompiled based to GL state. A possible cause could be uninitialised variables.
    {
        return;
    }

    const source_text = switch (source) {
        gl.DEBUG_SOURCE_API => "API",
        gl.DEBUG_SOURCE_APPLICATION => "Application",
        gl.DEBUG_SOURCE_SHADER_COMPILER => "Shader Compiler",
        gl.DEBUG_SOURCE_THIRD_PARTY => "Third Party",
        gl.DEBUG_SOURCE_WINDOW_SYSTEM => "Window System",
        gl.DEBUG_SOURCE_OTHER => "Other",
        else => "Unknown",
    };
    const type_text = switch (message_type) {
        gl.DEBUG_TYPE_DEPRECATED_BEHAVIOR => "Deprecated Behaviour",
        gl.DEBUG_TYPE_UNDEFINED_BEHAVIOR => "Undefined Behaviour",
        gl.DEBUG_TYPE_ERROR => "Error",
        gl.DEBUG_TYPE_MARKER => "Marker",
        gl.DEBUG_TYPE_PERFORMANCE => "Performance",
        gl.DEBUG_TYPE_POP_GROUP => "Pop Group",
        gl.DEBUG_TYPE_PUSH_GROUP => "Push Group",
        gl.DEBUG_TYPE_PORTABILITY => "Portability",
        gl.DEBUG_TYPE_OTHER => "Other",
        else => "Unknown",
    };
    const severity_text = switch (severity) {
        gl.DEBUG_SEVERITY_HIGH => "High Severity",
        gl.DEBUG_SEVERITY_MEDIUM => "Medium Severity",
        gl.DEBUG_SEVERITY_LOW => "Low Severity",
        gl.DEBUG_SEVERITY_NOTIFICATION => "Notification",
        else => "Unknown",
    };

    std.log.debug("OpenGL {s} message for {s} raised from {s}.\n#{d}: {s}", .{
        severity_text,
        type_text,
        source_text,
        id,
        message,
    });
}

pub fn glfwErrorCallback(error_code: c_int, description: *?[:0]const u8) callconv(.C) void {
    std.log.err("GLFW Error [#{d}]: {s}", .{ error_code, description });
}

pub fn glfwSizeCallback(_: *glfw.Window, width: gl.Sizei, height: gl.Sizei) callconv(.C) void {
    gl.viewport(0, 0, width, height);
}
