const std = @import("std");
const glfw = @import("zglfw");

pub const Bindings = struct {
    pub const Callback = *const fn (window: *glfw.Window, binding: []const u8, key: glfw.Key, action: glfw.Action, mods: glfw.Mods) void;
    const KeysTable = std.AutoHashMap(glfw.Key, []const u8);
    const CallbacksTable = std.StringHashMap(Callback);

    const Error = error{
        ActionNotFound,
    };

    var keys: KeysTable = undefined;
    var callbacks: CallbacksTable = undefined;

    pub fn init(alloc: std.mem.Allocator) void {
        keys = KeysTable.init(alloc);
        callbacks = CallbacksTable.init(alloc);
    }

    pub fn deinit() void {
        keys.deinit();
        callbacks.deinit();
    }

    pub fn registerBinding(binding: []const u8, callback: Callback) !void {
        try callbacks.put(binding, callback);
    }

    pub fn assignKey(binding: []const u8, key: glfw.Key) !void {
        if (!callbacks.contains(binding)) {
            return Error.ActionNotFound;
        }

        try keys.put(key, binding);
    }

    pub fn unassignKey(binding: []const u8) void {
        var key_it = keys.iterator();

        while (key_it.next()) |key| {
            if (std.mem.eql(u8, binding, key.value_ptr.*)) {
                keys.removeByPtr(key.key_ptr);
            }
        }
    }

    pub fn glfwKeyCallback(window: *glfw.Window, key: glfw.Key, _: i32, action: glfw.Action, mods: glfw.Mods) callconv(.C) void {
        if (key == .escape and action == .press) {
            window.setShouldClose(true);

            return;
        }

        const binding: []const u8 = keys.get(key) orelse "";

        if (action != .repeat) {
            std.log.debug("Binding: {s}, bound to {s} ({d}), Action: {s}", .{
                binding,
                getKeyName(key),
                @intFromEnum(key),
                switch (action) {
                    .press => "Pressed",
                    .release => "Released",
                    else => unreachable,
                },
            });
        }

        if (binding.len > 0) {
            const callback: Callback = callbacks.get(binding) orelse unreachable;

            callback(window, binding, key, action, mods);
        }
    }

    fn getKeyName(key: glfw.Key) []const u8 {
        const glfw_key_name = glfw.getKeyName(key, 0);

        if (glfw_key_name) |key_name| {
            return std.mem.span(key_name);
        } else {
            return switch (key) {
                .space => "Space",
                .escape => "Escape",
                .enter => "Enter",
                .tab => "Tab",
                .backspace => "Backspace",
                .insert => "Insert",
                .delete => "Delete",
                .right => "Right arrow",
                .left => "Left arrow",
                .down => "Down arrow",
                .up => "Up arrow",
                .page_up => "Page Up",
                .page_down => "Page Down",
                .home => "Home",
                .end => "End",
                .caps_lock => "Caps Lock",
                .scroll_lock => "Scroll Lock",
                .num_lock => "Num Lock",
                .print_screen => "Print Screen",
                .pause => "Pause",
                .F1 => "F1",
                .F2 => "F2",
                .F3 => "F3",
                .F4 => "F4",
                .F5 => "F5",
                .F6 => "F6",
                .F7 => "F7",
                .F8 => "F8",
                .F9 => "F9",
                .F10 => "F10",
                .F11 => "F11",
                .F12 => "F12",
                .F13 => "F13",
                .F14 => "F14",
                .F15 => "F15",
                .F16 => "F16",
                .F17 => "F17",
                .F18 => "F18",
                .F19 => "F19",
                .F20 => "F20",
                .F21 => "F21",
                .F22 => "F22",
                .F23 => "F23",
                .F24 => "F24",
                .F25 => "F25",
                .left_shift => "Left Shift",
                .left_control => "Left Ctrl",
                .left_alt => "Left Alt",
                .left_super => "Left Meta",
                .right_shift => "Right Shift",
                .right_control => "Right Ctrl",
                .right_alt => "Right Alt",
                .right_super => "Right Meta",
                .menu => "Menu",
                else => "Unknown",
            };
        }
    }
};
