const std = @import("std");
const gl = @import("zopengl").bindings;
const buffers = @import("../gl/bufferObjects.zig");
const Chunk = @import("Chunk.zig").Chunk;
const BlockModel = @import("../json/imports.zig").BlockModel;
const chunk_mesher = @import("chunkMesher.zig");

pub const ChunkMeshBufferPool = struct {
    const BufferEnum = enum(usize) { Vertex = 0, Instance = 1, Element = 2, Indirect = 3 };

    // pub const InstanceData = packed struct {
    //     data: u32,
    //     texture_id: u32,
    // };

    var allocator: std.mem.Allocator = undefined;

    // var vertex_data: []f32 = undefined;
    // var element_data: []u32 = undefined;
    // var instance_data: []InstanceData = undefined;
    // var indirect_data: []gl.DrawElementsIndirectCommand = undefined;

    // const vertex_list_size: comptime_int = 256;
    // const element_list_size: comptime_int = 384;
    // const instance_list_size: comptime_int = Chunk.chunk_volume;
    // const indirect_list_size: comptime_int = 32;

    const vertex_data: [24]f32 = .{
        // Block
        0.0, 0.0, 0.0,
        1.0, 0.0, 0.0,
        0.0, 1.0, 0.0,
        0.0, 0.0, 1.0,
        1.0, 1.0, 0.0,
        1.0, 0.0, 1.0,
        0.0, 1.0, 1.0,
        1.0, 1.0, 1.0,
    };
    const element_data: [36]u32 = .{
        // West
        1, 4, 7,
        1, 7, 5,
        // East
        3, 6, 2,
        3, 2, 0,
        // Top
        2, 6, 7,
        2, 7, 4,
        // Bottom
        1, 5, 3,
        1, 3, 0,
        // South
        0, 2, 4,
        0, 4, 1,
        // North
        5, 7, 6,
        5, 6, 3,
    };
    // The parameters can be described as:
    // .count = The number of vertices (indexed by elements) to render per-instance. Used to indicate how many vertices to draw, per type of block (e.g. block, ladder, stairs, etc.).
    // .instance_count = The number of instances to render. Used to indicate how many face meshes to render.
    // .first_index = The first index in the element buffer to start rendering from. Used to set the starting point for rendering different types of block per draw call.
    // .base_vertex = Sets the starting point of the first vertex in the vertex buffer to start rendering from.
    // .base_instance = Sets the starting point of the first instance in the instance buffer to start rendering from.
    const indirect_data: [6]gl.DrawElementsIndirectCommand = .{
        gl.DrawElementsIndirectCommand{ .count = 6, .instance_count = 3, .first_index = 0, .base_vertex = 0, .base_instance = 0 },
        gl.DrawElementsIndirectCommand{ .count = 6, .instance_count = 3, .first_index = 6, .base_vertex = 0, .base_instance = 3 },
        gl.DrawElementsIndirectCommand{ .count = 6, .instance_count = 3, .first_index = 12, .base_vertex = 0, .base_instance = 6 },
        gl.DrawElementsIndirectCommand{ .count = 6, .instance_count = 3, .first_index = 18, .base_vertex = 0, .base_instance = 9 },
        gl.DrawElementsIndirectCommand{ .count = 6, .instance_count = 3, .first_index = 24, .base_vertex = 0, .base_instance = 12 },
        gl.DrawElementsIndirectCommand{ .count = 6, .instance_count = 3, .first_index = 30, .base_vertex = 0, .base_instance = 15 },
    };

    var vao_id: u32 = undefined;
    var xbo_ids: [4]u32 = .{ undefined, undefined, undefined, undefined };

    pub fn setUp(alloc: std.mem.Allocator) !void {
        allocator = alloc;

        try setUpBuffers();
    }

    pub fn tearDown() void {
        tearDownBuffers();
    }

    pub fn readBlockModelsJson() !void {
        // const cube_model = try BlockModel.readFromJson(allocator, "assets/models/block.json");
        // var vertex_index: usize = 0;
        // var element_index: usize = 0;

        // for (0..6) |face| {
        //     for (cube_model.faces[face].vertices) |vertices| {
        //         vertex_data[vertex_index].position_x = vertices[0];
        //         vertex_data[vertex_index].position_y = vertices[1];
        //         vertex_data[vertex_index].position_z = vertices[1];
        //         vertex_data[vertex_index].normal_x = cube_model.faces[face].normal[0];
        //         vertex_data[vertex_index].normal_y = cube_model.faces[face].normal[1];
        //         vertex_data[vertex_index].normal_z = cube_model.faces[face].normal[2];
        //         vertex_index += 1;
        //     }

        //     for (cube_model.faces[face].elements) |elements| {
        //         element_data[element_index].element_1 = elements[0];
        //         element_data[element_index].element_2 = elements[1];
        //         element_data[element_index].element_3 = elements[2];
        //         element_index += 1;
        //     }
        // }

        // gl.bindVertexArray(vao_id);

        // gl.bindBuffer(gl.ARRAY_BUFFER, xbo_ids[@intFromEnum(BufferEnum.Vertex)]);
        // gl.bufferData(gl.ARRAY_BUFFER, @as(isize, @intCast(@sizeOf(VertexData) * vertex_index)), vertex_data.ptr, gl.STATIC_DRAW);

        // gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, xbo_ids[@intFromEnum(BufferEnum.Element)]);
        // gl.bufferData(gl.ELEMENT_ARRAY_BUFFER, @as(isize, @intCast(@sizeOf(ElementData) * element_index)), element_data.ptr, gl.STATIC_DRAW);

        // gl.bindVertexArray(0);
    }

    pub fn addChunkInstances() void {
        var chunk_data = Chunk.create(.{ 0, 0, 0 });
        // Reminder: data layout is YZX.
        chunk_data.blocks[0][0][0].material_type = 1;
        chunk_data.blocks[0][0][1].material_type = 1;
        chunk_data.blocks[1][2][0].material_type = 1;
        chunk_data.blocks[1][2][2].material_type = 1;
        chunk_data.blocks[1][2][3].material_type = 1;

        const chunk_mesh_data = chunk_mesher.createChunkMeshes(&chunk_data);

        gl.bindVertexArray(vao_id);
        gl.bindBuffer(gl.ARRAY_BUFFER, xbo_ids[@intFromEnum(BufferEnum.Instance)]);
        gl.bufferData(gl.ARRAY_BUFFER, @sizeOf(u32) * @as(isize, @intCast(chunk_mesh_data.count)), &chunk_mesh_data.data, gl.STATIC_DRAW);

        // var indirect_index: usize = 0;

        // indirect_data[indirect_index] = gl.DrawElementsIndirectCommand{
        //     .count = 0,
        //     .instance_count = 0,
        //     .first_index = 0,
        //     .base_vertex = 0,
        //     .base_instance = 0,
        // };
        // indirect_index += 1;

        // gl.bindBuffer(gl.DRAW_INDIRECT_BUFFER, xbo_ids[@intFromEnum(BufferEnum.Indirect)]);
        // gl.bufferData(gl.DRAW_INDIRECT_BUFFER, @sizeOf(gl.DrawElementsIndirectCommand) * indirect_index, indirect_data.ptr, gl.STATIC_DRAW);
    }

    pub fn draw() void {
        gl.bindVertexArray(vao_id);

        gl.multiDrawElementsIndirect(gl.TRIANGLES, gl.UNSIGNED_INT, null, indirect_data.len, 0);
    }

    fn setUpBuffers() !void {
        gl.genVertexArrays(1, &vao_id);
        gl.genBuffers(4, &xbo_ids);

        // vertex_data = try allocator.alloc(VertexData, vertex_list_size);
        // element_data = try allocator.alloc(ElementData, element_list_size);
        // instance_data = try allocator.alloc(InstanceData, instance_list_size);
        // indirect_data = try allocator.alloc(gl.DrawElementsIndirectCommand, indirect_list_size);

        gl.bindVertexArray(vao_id);
        gl.bindBuffer(gl.ARRAY_BUFFER, xbo_ids[@intFromEnum(BufferEnum.Vertex)]);
        gl.enableVertexAttribArray(0);
        gl.vertexAttribPointer(0, 3, gl.FLOAT, gl.FALSE, @sizeOf(f32) * 3, @ptrFromInt(0));
        gl.bufferData(gl.ARRAY_BUFFER, @sizeOf(f32) * vertex_data.len, &vertex_data, gl.STATIC_DRAW);

        gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, xbo_ids[@intFromEnum(BufferEnum.Element)]);
        gl.bufferData(gl.ELEMENT_ARRAY_BUFFER, @sizeOf(u32) * element_data.len, &element_data, gl.STATIC_DRAW);

        gl.bindBuffer(gl.ARRAY_BUFFER, xbo_ids[@intFromEnum(BufferEnum.Instance)]);
        gl.enableVertexAttribArray(1);
        gl.vertexAttribIPointer(1, 1, gl.UNSIGNED_INT, 0, null);
        gl.vertexAttribDivisor(1, 1);

        gl.bindBuffer(gl.DRAW_INDIRECT_BUFFER, xbo_ids[@intFromEnum(BufferEnum.Indirect)]);
        gl.bufferData(gl.DRAW_INDIRECT_BUFFER, @sizeOf(gl.DrawElementsIndirectCommand) * indirect_data.len, &indirect_data, gl.STATIC_DRAW);
    }

    fn tearDownBuffers() void {
        gl.deleteBuffers(4, &xbo_ids);
        gl.deleteVertexArrays(1, &vao_id);

        // allocator.free(vertex_data);
        // allocator.free(element_data);
        // allocator.free(instance_data);
        // allocator.free(indirect_data);
    }
};
