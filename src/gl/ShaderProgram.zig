const std = @import("std");
const gl = @import("zopengl").bindings;

const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

pub const ShaderStageTarget = enum(u32) {
    Vertex = gl.VERTEX_SHADER,
    Fragment = gl.FRAGMENT_SHADER,
    Geometry = gl.GEOMETRY_SHADER,
    TesselationControl = gl.TESS_CONTROL_SHADER,
    TesselationEnvironment = gl.TESS_EVALUATION_SHADER,
};

const ShaderStageUnionTag = enum {
    AsSource,
    AsFile,
    AsStage,
};

const ShaderStageUnion = union(ShaderStageUnionTag) {
    AsSource: struct {
        target: ShaderStageTarget,
        source: [*]const u8,
    },
    AsFile: struct {
        target: ShaderStageTarget,
        file_path: []const u8,
    },
    AsStage: ShaderStage,
};

pub const ShaderError = error{
    CompileFailed,
    LinkFailed,
    AlreadyAttached,
    AlreadyLinked,
    InvalidUniformType,
    InvalidUniformCount,
    UniformNotFound,
    OutOfMemory,
};

const UniformFuncsStruct = struct {
    Int: [4]*const fn (location: c_int, count: c_int, value: [*]const c_int) callconv(.C) void,
    UnsignedInt: [4]*const fn (location: c_int, count: c_int, value: [*]const c_uint) callconv(.C) void,
    Float: [4]*const fn (location: c_int, count: c_int, value: [*]const f32) callconv(.C) void,
    Double: [4]*const fn (location: c_int, count: c_int, value: [*]const f64) callconv(.C) void,
};

const UniformMatrixFuncsStruct = struct {
    Float: [3][3]*const fn (location: c_int, count: c_int, transpose: u8, value: [*c]const f32) callconv(.C) void,
    Double: [3][3]*const fn (location: c_int, count: c_int, transpose: u8, value: [*c]const f64) callconv(.C) void,
};

pub const ShaderStage = struct {
    shader_id: u32,
    stage_target: ShaderStageTarget,

    pub fn create(target: ShaderStageTarget, source: [*]const u8) ShaderError!ShaderStage {
        const shader_id = gl.createShader(@intFromEnum(target));

        errdefer {
            deleteShader(shader_id);
        }

        gl.shaderSource(shader_id, 1, &[_][*]const u8{source}, null);
        gl.compileShader(shader_id);

        var compiled: c_int = undefined;
        gl.getShaderiv(shader_id, gl.COMPILE_STATUS, &compiled);

        if (compiled == gl.FALSE) {
            var info_log: [512]u8 = undefined;
            var log_len: c_int = undefined;

            gl.getShaderInfoLog(shader_id, info_log.len, &log_len, &info_log);

            const message: []const u8 = if (log_len > 0) info_log[0..@intCast(log_len)] else "No message found.";

            const shader_type = switch (target) {
                .Vertex => "Vertex",
                .Fragment => "Fragment",
                .Geometry => "Geometry",
                .TesselationControl => "TesselationControl",
                .TesselationEnvironment => "TesselationEnvironment",
            };

            std.log.err("[GL] Shader compilation error!\nID: {d}, Type: {s}\n{s}", .{ shader_id, shader_type, message });

            return ShaderError.CompileFailed;
        }

        return ShaderStage{
            .shader_id = shader_id,
            .stage_target = target,
        };
    }

    pub fn destroy(self: *@This()) void {
        deleteShader(self.shader_id);
    }

    inline fn deleteShader(shader_id: u32) void {
        if (gl.isShader(shader_id) == gl.TRUE) {
            gl.deleteShader(shader_id);
        }
    }
};

pub const ShaderProgram = struct {
    program_id: u32,
    linked: bool,
    stages: ArrayList(ShaderStage),

    pub fn create(alloc: Allocator) Allocator.Error!ShaderProgram {
        const program_id = gl.createProgram();

        return ShaderProgram{
            .program_id = program_id,
            .linked = false,
            .stages = try ArrayList(ShaderStage).initCapacity(alloc, @typeInfo(ShaderStageTarget).Enum.fields.len),
        };
    }

    pub fn destroy(self: *@This()) void {
        gl.deleteProgram(self.program_id);

        for (self.stages.items) |*stage| {
            stage.destroy();
        }

        self.stages.deinit();
    }

    pub fn attach(self: *@This(), stage_union: ShaderStageUnion) anyerror!void {
        if (self.linked) {
            return ShaderError.AlreadyLinked;
        }

        switch (stage_union) {
            .AsSource => |data| {
                const stage = try ShaderStage.create(data.target, data.source);

                try self.attachShader(stage);
            },
            .AsFile => |file| {
                const shader_file = try std.fs.cwd().openFile(file.file_path, .{ .mode = .read_only });
                defer shader_file.close();

                var shader_buffer: [1024]u8 = undefined;
                var buffered_reader = std.io.bufferedReader(shader_file.reader());
                _ = try buffered_reader.reader().readAll(&shader_buffer);
                const stage = try ShaderStage.create(file.target, &shader_buffer);

                try self.attachShader(stage);
            },
            .AsStage => |stage| {
                try self.attachShader(stage);
            },
        }
    }

    inline fn attachShader(self: *@This(), stage: ShaderStage) ShaderError!void {
        gl.attachShader(self.program_id, stage.shader_id);

        try self.stages.append(stage);
    }

    pub fn link(self: *@This()) ShaderError!void {
        gl.linkProgram(self.program_id);

        var linked: c_int = undefined;
        gl.getProgramiv(self.program_id, gl.LINK_STATUS, &linked);

        if (linked == gl.FALSE) {
            var info_log: [512]u8 = undefined;
            var log_len: c_int = undefined;

            gl.getProgramInfoLog(self.program_id, info_log.len, &log_len, &info_log);

            const message: []const u8 = if (log_len > 0) info_log[0..@intCast(log_len)] else "No message found.";

            std.log.err("[GL] Program linker error!\nID: {d}\n{s}", .{ self.program_id, message });

            return ShaderError.LinkFailed;
        }
    }

    pub fn use(self: *@This()) void {
        gl.useProgram(self.program_id);
    }

    pub fn unuse() void {
        gl.useProgram(0);
    }

    pub fn setUniform(self: *@This(), name: [*c]const u8, elements: usize, count: usize, uniform_type: type, value: anytype) ShaderError!void {
        const location = gl.getUniformLocation(self.program_id, name);

        if (location == -1) {
            return ShaderError.UniformNotFound;
        }

        const uniform_funcs = UniformFuncsStruct{
            .Int = .{
                gl.uniform1iv,
                gl.uniform2iv,
                gl.uniform3iv,
                gl.uniform4iv,
            },
            .UnsignedInt = .{
                gl.uniform1uiv,
                gl.uniform2uiv,
                gl.uniform3uiv,
                gl.uniform4uiv,
            },
            .Float = .{
                gl.uniform1fv,
                gl.uniform2fv,
                gl.uniform3fv,
                gl.uniform4fv,
            },
            .Double = .{
                gl.uniform1dv,
                gl.uniform2dv,
                gl.uniform3dv,
                gl.uniform4dv,
            },
        };

        if (elements < 1 or elements > 4) {
            return ShaderError.InvalidUniformCount;
        }

        gl.useProgram(self.program_id);

        switch (uniform_type) {
            i32 => {
                uniform_funcs.Int[elements - 1](location, @intCast(count), @ptrCast(value));
            },
            u32 => {
                uniform_funcs.UnsignedInt[elements - 1](location, @intCast(count), @ptrCast(value));
            },
            f32 => {
                uniform_funcs.Float[elements - 1](location, @intCast(count), @ptrCast(value));
            },
            f64 => {
                uniform_funcs.Double[elements - 1](location, @intCast(count), @ptrCast(value));
            },
            else => {
                return ShaderError.InvalidUniformType;
            },
        }
    }

    pub fn setUniformMatrix(self: *@This(), name: [*c]const u8, rows: usize, columns: usize, count: usize, transpose: bool, uniform_type: type, value: anytype) ShaderError!void {
        const location = gl.getUniformLocation(self.program_id, name);
        const transpose_value: u8 = if (transpose) gl.FALSE else gl.TRUE;

        const uniform_matrix_funcs = UniformMatrixFuncsStruct{
            .Float = .{
                .{
                    gl.uniformMatrix2fv,
                    gl.uniformMatrix2x3fv,
                    gl.uniformMatrix2x4fv,
                },
                .{
                    gl.uniformMatrix3x2fv,
                    gl.uniformMatrix3fv,
                    gl.uniformMatrix3x4fv,
                },
                .{
                    gl.uniformMatrix4x2fv,
                    gl.uniformMatrix4x3fv,
                    gl.uniformMatrix4fv,
                },
            },
            .Double = .{
                .{
                    gl.uniformMatrix2dv,
                    gl.uniformMatrix2x3dv,
                    gl.uniformMatrix2x4dv,
                },
                .{
                    gl.uniformMatrix3x2dv,
                    gl.uniformMatrix3dv,
                    gl.uniformMatrix3x4dv,
                },
                .{
                    gl.uniformMatrix4x2dv,
                    gl.uniformMatrix4x3dv,
                    gl.uniformMatrix4dv,
                },
            },
        };

        if (rows < 2 or columns < 2 or rows > 4 or columns > 4) {
            return ShaderError.InvalidUniformCount;
        }

        gl.useProgram(self.program_id);

        switch (uniform_type) {
            f32 => {
                uniform_matrix_funcs.Float[rows - 2][columns - 2](location, @intCast(count), transpose_value, @ptrCast(value));
            },
            f64 => {
                uniform_matrix_funcs.Double[rows - 2][columns - 2](location, @intCast(count), transpose_value, @ptrCast(value));
            },
            else => {
                return ShaderError.InvalidUniformType;
            },
        }
    }
};
