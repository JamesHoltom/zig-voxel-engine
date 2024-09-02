const gl = @import("zopengl").bindings;

pub inline fn createBuffer() u32 {
    var xboId: c_uint = 0;

    gl.genBuffers(1, &xboId);

    return xboId;
}

pub inline fn createVertexArray() u32 {
    var vaoId: c_uint = 0;

    gl.genVertexArrays(1, &vaoId);

    return vaoId;
}

pub inline fn destroyBuffer(id: u32) void {
    gl.deleteBuffers(1, &id);
}

pub inline fn destroyVertexArray(id: u32) void {
    gl.deleteVertexArrays(1, &id);
}

pub inline fn bindBuffer(id: u32, target: comptime_int) void {
    gl.bindBuffer(target, id);
}

pub inline fn unbindBuffer(target: comptime_int) void {
    gl.bindBuffer(target, 0);
}

pub inline fn bindVertexArray(id: u32) void {
    gl.bindVertexArray(id);
}

pub inline fn unbindVertexArray() void {
    gl.bindVertexArray(0);
}
