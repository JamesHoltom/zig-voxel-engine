const std = @import("std");
const gl = @import("zopengl").bindings;
const TextureLoader = @import("../TextureLoader.zig").TextureLoader;
const Chunk = @import("Chunk.zig").Chunk;
const BlockModel = @import("../json/imports.zig").BlockModel;
const chunk_mesher = @import("chunkMesher.zig");

pub const ChunkMeshBufferPool = struct {
    const BufferEnum = enum(usize) { Vertex = 0, Instance = 1, Element = 2, Indirect = 3 };

    const Vec2 = packed struct {
        x: f32,
        y: f32,
    };
    const Vec3 = packed struct {
        x: f32,
        y: f32,
        z: f32,
    };
    const VertexData = packed struct {
        position: Vec3,
        uv: Vec2,
    };

    const vertex_position_data: [4]VertexData = .{
        // Block
        .{ .position = .{ .x = 0.0, .y = 0.0, .z = 0.0 }, .uv = .{ .x = 0.0, .y = 0.0 } },
        .{ .position = .{ .x = 1.0, .y = 0.0, .z = 0.0 }, .uv = .{ .x = 1.0, .y = 0.0 } },
        .{ .position = .{ .x = 0.0, .y = 1.0, .z = 0.0 }, .uv = .{ .x = 0.0, .y = 1.0 } },
        .{ .position = .{ .x = 1.0, .y = 1.0, .z = 0.0 }, .uv = .{ .x = 1.0, .y = 1.0 } },
    };
    const element_data: [6]u32 = .{
        0, 2, 3,
        0, 3, 1,
    };

    var draw_count: isize = 0;

    var vao_id: u32 = undefined;
    var xbo_ids: [4]u32 = .{ undefined, undefined, undefined, undefined };
    var tex_id: u32 = 0;

    pub fn init(allocator: std.mem.Allocator) !void {
        try setUpBuffers();
        try setUpTextures(allocator);
    }

    pub fn deinit() void {
        tearDownBuffers();
        tearDownTextures();
    }

    pub fn draw() void {
        gl.bindTextureUnit(0, tex_id);
        gl.bindVertexArray(vao_id);
        gl.bindBuffer(gl.DRAW_INDIRECT_BUFFER, xbo_ids[@intFromEnum(BufferEnum.Indirect)]);

        gl.multiDrawElementsIndirect(gl.TRIANGLES, gl.UNSIGNED_INT, null, @intCast(draw_count), 0);
    }

    pub fn addChunkInstances(allocator: std.mem.Allocator) !void {
        var chunk_data = Chunk.create(.{ 0, 0, 0 });
        // Reminder: data layout is YZX.
        chunk_data.blocks[0][0][0].material_type = 1;
        chunk_data.blocks[0][0][2].material_type = 1;
        chunk_data.blocks[2][0][0].material_type = 1;
        chunk_data.blocks[0][2][0].material_type = 1;

        chunk_data.blocks[3][1][1].material_type = 1;
        chunk_data.blocks[3][0][1].material_type = 1;
        chunk_data.blocks[3][1][0].material_type = 1;
        chunk_data.blocks[2][1][1].material_type = 1;

        chunk_data.blocks[1][3][3].material_type = 1;
        chunk_data.blocks[2][3][3].material_type = 1;
        chunk_data.blocks[3][1][3].material_type = 1;
        chunk_data.blocks[3][2][3].material_type = 1;
        chunk_data.blocks[3][3][1].material_type = 1;
        chunk_data.blocks[3][3][2].material_type = 1;

        const chunk_mesh_data = try chunk_mesher.createChunkMeshes(allocator, &chunk_data);
        const instance_count = chunk_mesh_data.data.items.len;
        defer {
            chunk_mesh_data.data.deinit();
            chunk_mesh_data.draw_commands.deinit();
        }

        draw_count = @as(isize, @intCast(chunk_mesh_data.draw_commands.items.len));

        gl.namedBufferData(xbo_ids[@intFromEnum(BufferEnum.Instance)], @sizeOf(u32) * @as(isize, @intCast(instance_count)), chunk_mesh_data.data.items.ptr, gl.STATIC_DRAW);
        gl.namedBufferData(xbo_ids[@intFromEnum(BufferEnum.Indirect)], @sizeOf(gl.DrawElementsIndirectCommand) * @as(isize, @intCast(draw_count)), chunk_mesh_data.draw_commands.items.ptr, gl.STATIC_DRAW);
    }

    fn setUpBuffers() !void {
        gl.createVertexArrays(1, &vao_id);
        gl.createBuffers(4, &xbo_ids);

        gl.namedBufferData(xbo_ids[@intFromEnum(BufferEnum.Vertex)], @sizeOf(VertexData) * vertex_position_data.len, &vertex_position_data, gl.STATIC_DRAW);
        gl.namedBufferData(xbo_ids[@intFromEnum(BufferEnum.Element)], @sizeOf(u32) * element_data.len, &element_data, gl.STATIC_DRAW);

        gl.enableVertexArrayAttrib(vao_id, 0);
        gl.enableVertexArrayAttrib(vao_id, 1);
        gl.enableVertexArrayAttrib(vao_id, 2);
        gl.vertexArrayAttribBinding(vao_id, 0, 0);
        gl.vertexArrayAttribBinding(vao_id, 1, 0);
        gl.vertexArrayAttribBinding(vao_id, 2, 1);
        gl.vertexArrayAttribFormat(vao_id, 0, 3, gl.FLOAT, gl.FALSE, @offsetOf(VertexData, "position"));
        gl.vertexArrayAttribFormat(vao_id, 1, 2, gl.FLOAT, gl.FALSE, @offsetOf(VertexData, "uv"));
        gl.vertexArrayAttribIFormat(vao_id, 2, 1, gl.UNSIGNED_INT, 0);
        gl.vertexArrayBindingDivisor(vao_id, 1, 1);

        gl.vertexArrayVertexBuffer(vao_id, 0, xbo_ids[@intFromEnum(BufferEnum.Vertex)], 0, @sizeOf(VertexData));
        gl.vertexArrayElementBuffer(vao_id, xbo_ids[@intFromEnum(BufferEnum.Element)]);
        gl.vertexArrayVertexBuffer(vao_id, 1, xbo_ids[@intFromEnum(BufferEnum.Instance)], 0, @sizeOf(u32));
        gl.vertexArrayVertexBuffer(vao_id, 2, xbo_ids[@intFromEnum(BufferEnum.Indirect)], 0, @sizeOf(gl.DrawElementsIndirectCommand));
    }

    fn setUpTextures(allocator: std.mem.Allocator) !void {
        var dirt_image = try TextureLoader.loadFromFile(allocator, "assets/materials/dirt.png");
        defer dirt_image.deinit();

        gl.createTextures(gl.TEXTURE_2D, 1, &tex_id);
        gl.textureParameteri(tex_id, gl.TEXTURE_MIN_FILTER, gl.LINEAR);
        gl.textureParameteri(tex_id, gl.TEXTURE_MAG_FILTER, gl.LINEAR);
        gl.textureParameteri(tex_id, gl.TEXTURE_WRAP_S, gl.REPEAT);
        gl.textureParameteri(tex_id, gl.TEXTURE_WRAP_T, gl.REPEAT);
        gl.textureStorage2D(tex_id, 1, gl.RGB8, @intCast(dirt_image.width), @intCast(dirt_image.height));
        gl.textureSubImage2D(tex_id, 0, 0, 0, @intCast(dirt_image.width), @intCast(dirt_image.height), gl.RGB, gl.UNSIGNED_BYTE, @ptrCast(dirt_image.data));
        gl.generateTextureMipmap(tex_id);
    }

    fn tearDownBuffers() void {
        gl.deleteBuffers(4, &xbo_ids);
        gl.deleteVertexArrays(1, &vao_id);
    }

    fn tearDownTextures() void {
        gl.deleteTextures(1, &tex_id);
    }
};
