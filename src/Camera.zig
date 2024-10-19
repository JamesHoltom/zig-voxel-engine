const std = @import("std");
const glfw = @import("zglfw");
const math = @import("zmath");

/// __Enumerations__:
/// * _FixedY_: Camera movement is fixed to the Y axis, and can move freely on the XZ axes.
/// * _Free_: Camera can move freely on the XYZ axes.
pub const MovementType = enum {
    FixedY,
    Free,
};

pub const Camera = struct {
    pub const fixed_up = math.f32x4(0.0, 1.0, 0.0, 0.0);

    position: math.F32x4,
    rotation: math.F32x4,
    forward: math.F32x4,
    right: math.F32x4,
    up: math.F32x4,
    movement_type: MovementType,

    pub fn create(position: [3]f32, rotation: [3]f32) Camera {
        var camera = Camera{
            .position = math.loadArr3(position),
            .rotation = math.loadArr3(rotation),
            .forward = undefined,
            .right = undefined,
            .up = undefined,
            .movement_type = .FixedY,
        };

        camera.updateNormals();

        return camera;
    }

    pub fn moveTo(self: *@This(), position: [3]f32) void {
        self.position = math.loadArr3(position);
    }

    pub fn moveBy(self: *@This(), offset: [3]f32) void {
        self.position += math.loadArr3(offset);
    }

    pub fn rotateTo(self: *@This(), rotation: [3]f32) void {
        self.rotation = math.modAngle(math.loadArr3(rotation));

        self.updateNormals();
    }

    pub fn rotateBy(self: *@This(), offset: [3]f32) void {
        const offset_vec = math.loadArr3(offset);

        self.rotation = math.modAngle(self.rotation + offset_vec);

        self.updateNormals();
    }

    pub fn cycleMovementTypes(self: *@This()) void {
        self.movement_type = if (self.movement_type == .FixedY) .Free else .FixedY;

        self.updateNormals();
    }

    pub fn getMvpMatrix(self: *@This(), window: *glfw.Window) math.Mat {
        const framebuffer_size = window.getFramebufferSize();
        const aspect_ratio = @as(f32, @floatFromInt(framebuffer_size[0])) / @as(f32, @floatFromInt(framebuffer_size[1]));
        const fov: f32 = 0.25 * std.math.pi;
        const near: f32 = 0.1;
        const far: f32 = 100.0;

        const identity = math.identity();
        const perspective = math.perspectiveFovRhGl(fov, aspect_ratio, near, far);
        const camera = math.lookToRh(self.position, self.forward, self.up);

        return math.mul(math.mul(identity, camera), perspective);
    }

    fn updateNormals(self: *@This()) void {
        self.forward = math.normalize3(math.mul(math.f32x4(0.0, 0.0, 1.0, 0.0), math.matFromRollPitchYaw(self.rotation[0], self.rotation[1], self.rotation[2])));
        self.right = math.normalize3(math.cross3(fixed_up, self.forward));
        self.up = math.normalize3(math.cross3(self.forward, self.right));
    }
};
