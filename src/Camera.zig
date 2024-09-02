const std = @import("std");
const math = @import("zmath");
const State = @import("State.zig").State;

pub const MovementType = enum {
    Fixed,
    FixedY,
    Free,
};

pub const Camera = struct {
    position: math.F32x4,
    rotation: math.F32x4,
    forward: math.F32x4,
    up: math.F32x4,
    movement_type: MovementType,
    movement_speed: f32,
    turn_speed: f32,

    pub fn create(position: [3]f32, rotation: [3]f32) Camera {
        return Camera{
            .position = math.loadArr3(position),
            .rotation = math.loadArr3(rotation),
            .forward = math.f32x4s(0.0),
            .up = math.f32x4(0.0, 1.0, 0.0, 0.0),
            .movement_type = .FixedY,
            .movement_speed = 2.0,
            .turn_speed = 1.0,
        };
    }

    pub fn moveTo(self: *@This(), position: [3]f32) void {
        self.position = math.loadArr3(position);
    }

    pub fn moveBy(self: *@This(), offset: [3]f32) void {
        self.position += math.loadArr3(offset);
    }

    pub fn rotateTo(self: *@This(), rotation: [3]f32) void {
        self.rotation = math.modAngle(math.loadArr3(rotation));
    }

    pub fn rotateBy(self: *@This(), offset: [3]f32) void {
        const offset_vec = math.loadArr3(offset);

        self.rotation = math.modAngle(self.rotation + offset_vec);
    }

    pub fn cycleMovementTypes(self: *@This()) void {
        switch (self.movement_type) {
            .Fixed => {
                self.movement_type = .FixedY;
            },
            .FixedY => {
                self.movement_type = .Free;
            },
            .Free => {
                self.movement_type = .Fixed;
            },
        }
    }

    pub fn doInput(self: *@This(), state: State, timestep: f64) void {
        const stepped_movement_speed: f32 = self.movement_speed * @as(f32, @floatCast(timestep));
        const stepped_turn_speed: f32 = self.turn_speed * @as(f32, @floatCast(timestep));

        if (state.window.getKey(.left) == .press) {
            self.rotation[1] += stepped_turn_speed;
        } else if (state.window.getKey(.right) == .press) {
            self.rotation[1] -= stepped_movement_speed;
        }

        if (state.window.getKey(.up) == .press) {
            self.rotation[0] -= stepped_turn_speed;
        } else if (state.window.getKey(.down) == .press) {
            self.rotation[0] += stepped_movement_speed;
        }

        const forward_value = math.mul(math.f32x4(0.0, 0.0, 1.0, 0.0), math.matFromRollPitchYaw(self.rotation[0], self.rotation[1], self.rotation[2]));

        self.forward = math.normalize3(forward_value);

        const forward: math.F32x4 = switch (self.movement_type) {
            .Fixed => math.loadArr3(.{ 0.0, 0.0, 1.0 }),
            .FixedY => blk: {
                var y_fixed = forward_value;
                y_fixed[1] = 0.0;

                break :blk math.normalize3(y_fixed);
            },
            .Free => self.forward,
        };
        const right = math.normalize3(math.cross3(math.f32x4(0.0, 1.0, 0.0, 0.0), forward));
        const up = math.normalize3(math.cross3(forward, right));

        const speed_vec = math.splat(math.F32x4, stepped_movement_speed);

        if (state.window.getKey(.w) == .press) {
            self.position += forward * speed_vec;
        } else if (state.window.getKey(.s) == .press) {
            self.position -= forward * speed_vec;
        }

        if (state.window.getKey(.a) == .press) {
            self.position += right * speed_vec;
        } else if (state.window.getKey(.d) == .press) {
            self.position -= right * speed_vec;
        }

        if (state.window.getKey(.space) == .press) {
            self.position += up * speed_vec;
        } else if (state.window.getKey(.left_shift) == .press) {
            self.position -= up * speed_vec;
        }
    }

    pub fn getMvpMatrix(self: *@This(), state: State) math.Mat {
        const fov: f32 = 0.25 * std.math.pi;
        const aspect_ratio = state.getAspectRatio();
        const near: f32 = 0.1;
        const far: f32 = 100.0;

        const identity = math.identity();
        const perspective = math.perspectiveFovRhGl(fov, aspect_ratio, near, far);
        const camera = math.lookToRh(self.position, self.forward, self.up);

        return math.mul(math.mul(identity, camera), perspective);
    }
};
