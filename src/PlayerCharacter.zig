const std = @import("std");
const glfw = @import("zglfw");
const math = @import("zmath");
const Camera = @import("Camera.zig").Camera;
const Bindings = @import("input/Bindings.zig").Bindings;
const Timestep = @import("Timestep.zig").Timestep;

pub const PlayerCharacter = struct {
    pub const InputFlags = enum(u8) {
        NoInput = 0,
        MouseOnly = 1,
        KeysOnly = 2,
        MouseAndKeys = 3,
    };

    pub var camera: Camera = undefined;
    pub var move_speed: f64 = 2.0;
    pub var turn_speed: f64 = 1.5;
    pub var input_flags: InputFlags = undefined;
    var input: [10]i8 = .{0} ** 10;

    pub fn init() !void {
        camera = Camera.create([_]f32{ 0.5, 0.5, -5.0 }, [_]f32{ 0.0, 0.0, 0.0 });
        input_flags = .KeysOnly;

        try Bindings.registerBinding("ply_cycleCam", &cycleMovementTypes);
        try Bindings.registerBinding("ply_cycleInputType", &cycleInputTypes);
        try Bindings.registerBinding("ply_moveForward", &doMovementInput);
        try Bindings.registerBinding("ply_moveBackward", &doMovementInput);
        try Bindings.registerBinding("ply_strafeLeft", &doMovementInput);
        try Bindings.registerBinding("ply_strafeRight", &doMovementInput);
        try Bindings.registerBinding("ply_flyUp", &doMovementInput);
        try Bindings.registerBinding("ply_flyDown", &doMovementInput);
        try Bindings.registerBinding("ply_lookLeft", &doRotationInput);
        try Bindings.registerBinding("ply_lookRight", &doRotationInput);
        try Bindings.registerBinding("ply_lookUp", &doRotationInput);
        try Bindings.registerBinding("ply_lookDown", &doRotationInput);
    }

    pub fn update() void {
        const move_x_input: i8 = input[2] - input[3];
        const move_y_input: i8 = input[4] - input[5];
        const move_z_input: i8 = input[0] - input[1];
        const turn_x_input: i8 = input[6] - input[7];
        const turn_y_input: i8 = input[9] - input[8];

        var movement: math.F32x4 = (camera.forward * math.f32x4s(@as(f32, @floatFromInt(move_z_input)) * @as(f32, @floatCast(move_speed * Timestep.get()))));
        movement += (camera.right * math.f32x4s(@as(f32, @floatFromInt(move_x_input)) * @as(f32, @floatCast(move_speed * Timestep.get()))));

        // FIXME: Constrain player movement on Y axis kanpilotID(olb7klheq7kjsfdyey8djjgu)
        movement += switch (camera.movement_type) {
            .FixedY => (Camera.fixed_up * math.f32x4s(@as(f32, @floatFromInt(move_y_input)) * @as(f32, @floatCast(move_speed * Timestep.get())))),
            .Free => (camera.up * math.f32x4s(@as(f32, @floatFromInt(move_y_input)) * @as(f32, @floatCast(move_speed * Timestep.get())))),
        };

        camera.moveBy(math.vecToArr3(movement));
        camera.rotateBy(.{
            @as(f32, @floatFromInt(turn_y_input)) * @as(f32, @floatCast(turn_speed * Timestep.get())),
            @as(f32, @floatFromInt(turn_x_input)) * @as(f32, @floatCast(turn_speed * Timestep.get())),
            0.0,
        });
    }

    fn doMovementInput(_: *glfw.Window, binding: []const u8, _: glfw.Key, action: glfw.Action, _: glfw.Mods) void {
        if (std.mem.eql(u8, binding, "ply_moveForward")) {
            input[0] = @intFromBool(action != .release);
        } else if (std.mem.eql(u8, binding, "ply_moveBackward")) {
            input[1] = @intFromBool(action != .release);
        } else if (std.mem.eql(u8, binding, "ply_strafeLeft")) {
            input[2] = @intFromBool(action != .release);
        } else if (std.mem.eql(u8, binding, "ply_strafeRight")) {
            input[3] = @intFromBool(action != .release);
        } else if (std.mem.eql(u8, binding, "ply_flyUp")) {
            input[4] = @intFromBool(action != .release);
        } else if (std.mem.eql(u8, binding, "ply_flyDown")) {
            input[5] = @intFromBool(action != .release);
        }
    }

    fn doRotationInput(_: *glfw.Window, binding: []const u8, _: glfw.Key, action: glfw.Action, _: glfw.Mods) void {
        if (std.mem.eql(u8, binding, "ply_lookLeft")) {
            input[6] = @intFromBool(action != .release);
        } else if (std.mem.eql(u8, binding, "ply_lookRight")) {
            input[7] = @intFromBool(action != .release);
        } else if (std.mem.eql(u8, binding, "ply_lookUp")) {
            input[8] = @intFromBool(action != .release);
        } else if (std.mem.eql(u8, binding, "ply_lookDown")) {
            input[9] = @intFromBool(action != .release);
        }
    }

    fn cycleMovementTypes(_: *glfw.Window, _: []const u8, _: glfw.Key, action: glfw.Action, _: glfw.Mods) void {
        if (action == .press) {
            camera.cycleMovementTypes();
        }
    }

    fn cycleInputTypes(window: *glfw.Window, _: []const u8, _: glfw.Key, action: glfw.Action, _: glfw.Mods) void {
        if (action == .press) {
            switch (input_flags) {
                .KeysOnly => {
                    window.setInputMode(.cursor, glfw.Cursor.Mode.disabled);
                    PlayerCharacter.input_flags = .MouseOnly;
                },
                .MouseOnly => {
                    window.setInputMode(.cursor, glfw.Cursor.Mode.normal);
                    PlayerCharacter.input_flags = .KeysOnly;
                },
                else => unreachable,
            }
        }
    }
};
