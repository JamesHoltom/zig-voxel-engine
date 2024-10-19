const std = @import("std");
const gl = @import("zopengl").bindings;
const Chunk = @import("Chunk.zig").Chunk;
const Block = @import("../block/Block.zig").Block;

pub const InstanceList = std.ArrayList(u32);
pub const DEICList = std.ArrayList(gl.DrawElementsIndirectCommand);

pub const MeshData = struct {
    data: InstanceList,
    draw_commands: DEICList,
};
const SolidMaskData = [3][padded_chunk_length][padded_chunk_length]u64;
const EdgeMaskData = [6][Chunk.chunk_length][Chunk.chunk_length]u32;
const FaceData = [6][Chunk.chunk_length][Chunk.chunk_length]u32;

const padded_chunk_length: comptime_int = Chunk.chunk_length + 2;

pub var draw_mode: i32 = -1;

pub fn createChunkMeshes(allocator: std.mem.Allocator, chunk_data: *const Chunk) !MeshData {
    var solid_mask_data: SolidMaskData = std.mem.zeroes(SolidMaskData);
    var edge_mask_data: EdgeMaskData = std.mem.zeroes(EdgeMaskData);
    var face_data: FaceData = std.mem.zeroes(FaceData);

    // Part 1: Generate the mask data for solid voxels on each face.
    for (0..padded_chunk_length) |y| {
        const u_y: isize = @as(isize, @intCast(y)) - 1;

        for (0..padded_chunk_length) |z| {
            const u_z: isize = @as(isize, @intCast(z)) - 1;

            for (0..padded_chunk_length) |x| {
                const u_x: isize = @as(isize, @intCast(x)) - 1;
                const block = getWorldToSampleBlock(chunk_data, u_x, u_y, u_z) orelse Block.air();

                if (block.material_type > 0) {
                    // For the east/west faces, generate the mask data on:
                    //   * The Z row.
                    //   * The Y column.
                    //   * The X line.
                    solid_mask_data[0][@intCast(y)][@intCast(z)] |= @as(u64, 1) << @as(u6, @intCast(x));

                    // For the top/bottom faces, generate the mask data on:
                    //   * The X row.
                    //   * The Z column.
                    //   * The Y line.
                    solid_mask_data[1][@intCast(z)][@intCast(x)] |= @as(u64, 1) << @as(u6, @intCast(y));

                    // For the north/south faces, generate the mask data on:
                    //   * The X row.
                    //   * The Y column.
                    //   * The Z line.
                    solid_mask_data[2][@intCast(y)][@intCast(x)] |= @as(u64, 1) << @as(u6, @intCast(z));
                }
            }
        }
    }

    // Part 1.5: Log the mask data for solid voxels.
    // const solid_file = try std.fs.cwd().createFile("logs/tempSolid.log", .{ .truncate = true });
    // for (solid_mask_data, 0..) |axis_mask, solid_axis| {
    //     const axis_buf: []const u8 = "On " ++ switch (solid_axis) {
    //         0 => "X",
    //         1 => "Y",
    //         2 => "Z",
    //         else => " ",
    //     } ++ " axis:\n";
    //     _ = try solid_file.write(axis_buf);
    //     for (axis_mask) |layer| {
    //         for (layer) |mask| {
    //             const row = try std.fmt.allocPrint(allocator, "{b:0>64}\n", .{mask});
    //             _ = try solid_file.write(row);
    //             allocator.free(row);
    //         }

    //         _ = try solid_file.write("\n");
    //     }
    // }
    // solid_file.close();

    // Part 2: Generate the mask data for voxels with a renderable face on each axis.
    for (0..3) |face| {
        for (1..padded_chunk_length - 1) |row| {
            for (1..padded_chunk_length - 1) |column| {
                // Using bit manipulation, find the edges (i.e. the leading/trailing bit at any given location).
                // To get the positive (left-facing) face:
                //   In: 0b0100010111111110000011111111001111
                //  >>1: 0b0010001011111111000001111111100111
                //    !: 0b1101110100000000111110000000011000
                //    &: 0b0100010100000000000010000000001000
                //  Out:  0b10001010000000000001000000000100
                // To get the negative (right-facing) face:
                //   In: 0b0100010111111110000011111111001111
                //  <<1: 0b1000101111111100000111111110011110
                //    !: 0b0111010000000011111000000001100001
                //    &: 0b0100010000000010000000000001000001
                //  Out:  0b10001000000001000000000000100000
                const line = solid_mask_data[face][row][column];

                if (line != 0) {
                    const positive_mask: u64 = line & ~(line >> 1);
                    const negative_mask: u64 = line & ~(line << 1);

                    edge_mask_data[face * 2][row - 1][column - 1] = @truncate(positive_mask >> 1);
                    edge_mask_data[(face * 2) + 1][row - 1][column - 1] = @truncate(negative_mask >> 1);

                    // std.debug.print("Face {d}\nBefore: {b:0>34}\nLeft:    {b:0>32}\nRight:   {b:0>32}\n", .{
                    //     face,
                    //     row,
                    //     edge_mask_data[face * 2][layer - 1][column - 1],
                    //     edge_mask_data[(face * 2) + 1][layer - 1][column - 1],
                    // });
                }
            }
        }
    }

    // Part 2.5: Log the mask data for voxel edges.
    // const edge_file = try std.fs.cwd().createFile("logs/tempEdge.log", .{ .truncate = true });
    // for (edge_mask_data, 0..) |face_mask, face| {
    //     const axis_data = try std.fmt.allocPrint(allocator, "On face #{d}:\n", .{face});
    //     _ = try edge_file.write(axis_data);
    //     allocator.free(axis_data);

    //     for (face_mask) |layer| {
    //         for (layer) |mask| {
    //             const row = try std.fmt.allocPrint(allocator, "{b:0>64}\n", .{mask});
    //             _ = try edge_file.write(row);
    //             allocator.free(row);
    //         }

    //         _ = try edge_file.write("\n");
    //     }
    // }
    // edge_file.close();

    // Part 3: Convert the edge mask data into faces to greedy mesh.
    for (0..6) |face| {
        for (0..Chunk.chunk_length) |z| {
            for (0..Chunk.chunk_length) |x| {
                var data = edge_mask_data[face][z][x];
                while (data != 0) {
                    const y: u32 = @ctz(data);

                    data &= data - 1;

                    face_data[face][y][z] |= @as(u32, 1) << @as(u5, @intCast(x));
                }
            }
        }
    }

    // Part 3.5: Log the mask data for meshable faces.
    // const face_file = try std.fs.cwd().createFile("logs/tempFace.log", .{ .truncate = true });
    // for (face_data, 0..) |data, face| {
    //     const axis_data = try std.fmt.allocPrint(allocator, "On face #{d}:\n", .{face});
    //     _ = try edge_file.write(axis_data);
    //     allocator.free(axis_data);

    //     for (data) |row| {
    //         for (row) |column| {
    //             const column_data = try std.fmt.allocPrint(allocator, "{b:0>64}\n", .{column});
    //             _ = try face_file.write(column_data);
    //             allocator.free(column_data);
    //         }

    //         _ = try face_file.write("\n");
    //     }
    // }
    // face_file.close();

    // Part 4: Convert the mask data into meshes to insert into the data lists.
    var mesh_data: MeshData = .{
        .data = InstanceList.init(allocator),
        .draw_commands = DEICList.init(allocator),
    };
    var total_mesh_count: usize = 0;
    // const mesh_file = try std.fs.cwd().createFile("logs/tempMesh.log", .{ .truncate = true });

    for (0..6) |face| {
        if (draw_mode != -1 and draw_mode != face) {
            // const skip_str = try std.fmt.allocPrint(allocator, "Skipping face #{d}...\n", .{face});
            // _ = try mesh_file.write(skip_str);
            // allocator.free(skip_str);

            continue;
        }

        var mesh_count: usize = 0;
        // const face_str = try std.fmt.allocPrint(allocator, "On face #{d}:\n", .{face});
        // _ = try mesh_file.write(face_str);
        // allocator.free(face_str);

        for (0..Chunk.chunk_length) |z| {
            for (0..Chunk.chunk_length) |x| {
                // var data: usize = 0;
                var y: usize = 0;

                while (y < Chunk.chunk_length) {
                    // Find the offset to the nearest row.
                    // This is done by counting the number of trailing zeros.
                    // E.g. @ctz(0b01111000) will return 3.
                    y = @ctz(face_data[face][z][x]);

                    // If we've reached the start of the row, break out of the loop.
                    if (y >= Chunk.chunk_length) {
                        break;
                    }

                    // Calculate the width of the mesh.
                    // This is done by offseting the mask data by the offset in step 1, then counting the number of trailing ones.
                    // E.g. @ctz(~(0b01111000 >> 3)) will return 4.
                    const width: u32 = @ctz(~face_data[face][z][x] >> @as(u5, @intCast(y)));

                    // Step 3: Generate a mask from the offset and width, to compare against other columns.
                    const width_mask: u32 = ((@as(u32, 1) << @as(u5, @intCast(width))) - 1) << @as(u5, @intCast(y));
                    var height: u32 = 1;
                    var next_column = x + 1;

                    while (next_column < Chunk.chunk_length) : (next_column += 1) {
                        const row_mask = face_data[face][z][next_column];

                        // Step 4a: If the next column does not match the mask from step 3, break out of the loop.
                        if (row_mask & width_mask != width_mask) {
                            break;
                        } else {
                            // Step 4b: Remove the bits from the edge mask data, so they do not get counted towards other meshes.
                            face_data[face][z][next_column] &= ~width_mask;

                            height += 1;
                        }
                    }

                    face_data[face][z][x] &= ~width_mask;

                    // Step 6: Append the mesh data to the list.
                    const value: u32 = switch (face) {
                        0, 1 => @as(u32, @intCast(z)) | (@as(u32, @intCast(x)) << 5) | (@as(u32, @intCast(y)) << 10) | (width << 15) | (height << 20),
                        2, 3 => @as(u32, @intCast(y)) | (@as(u32, @intCast(z)) << 5) | (@as(u32, @intCast(x)) << 10) | (width << 15) | (height << 20),
                        4, 5 => @as(u32, @intCast(y)) | (@as(u32, @intCast(x)) << 5) | (@as(u32, @intCast(z)) << 10) | (width << 15) | (height << 20),
                        else => unreachable,
                    };
                    try mesh_data.data.append(value);

                    // const mesh_buf = try std.fmt.allocPrint(allocator, "#{d}, X: {d: >2}, Y: {d: >2}, Z: {d: >2}, W: {d: >2}, H: {d: >2}, Value: {b:0>32}\n", .{
                    //     mesh_count,
                    //     value & 31,
                    //     (value >> 5) & 31,
                    //     (value >> 10) & 31,
                    //     width,
                    //     height,
                    //     value,
                    // });
                    // _ = try mesh_file.write(mesh_buf);
                    // allocator.free(mesh_buf);

                    mesh_count += 1;
                }
            }
        }

        // _ = try mesh_file.write("\n");

        // Step 7: At the end of each face, create the draw commands for the data.
        // The parameters can be described as:
        // .count = The number of vertices (indexed by elements) to render per-instance. Used to indicate how many vertices to draw, per type of block (e.g. block, ladder, stairs, etc.).
        // .instance_count = The number of instances to render. Used to indicate how many face meshes to render.
        // .first_index = The first index in the element buffer to start rendering from. Used to set the starting point for rendering different types of block per draw call.
        // .base_vertex = Sets the starting point of the first vertex in the vertex buffer to start rendering from.
        // .base_instance = Sets the starting point of the first instance in the instance buffer to start rendering from.
        try mesh_data.draw_commands.append(.{
            .count = 6,
            .instance_count = @as(c_uint, @intCast(mesh_count)),
            .first_index = 0,
            .base_vertex = 0,
            .base_instance = @as(c_uint, @intCast(total_mesh_count)),
        });

        total_mesh_count += mesh_count;
        std.log.debug("Face: {d}, Count: {d}, Total: {d}", .{ face, mesh_count, total_mesh_count });
    }

    // mesh_file.close();

    std.log.debug("Reduced to {d} meshes.", .{total_mesh_count});

    return mesh_data;
}

fn getWorldToSampleBlock(chunk_data: *const Chunk, x: isize, y: isize, z: isize) ?Block {
    // We only check the 6 neighbour chunks adjacent to the edges. Blocks on the diagonals & corners (the other 20 neighbours) can be ignored.
    const on_x_any_edge = (x == Chunk.chunk_length) or (x == -1);
    const on_y_any_edge = (y == Chunk.chunk_length) or (y == -1);
    const on_z_any_edge = (z == Chunk.chunk_length) or (z == -1);

    if (on_x_any_edge and !on_y_any_edge and !on_z_any_edge) {
        if (x == -1) {
            if (chunk_data.neighbours[0]) |neighbour| {
                return neighbour.blocks[@intCast(y)][@intCast(z)][Chunk.chunk_length - 1];
            }
        } else {
            if (chunk_data.neighbours[1]) |neighbour| {
                return neighbour.blocks[@intCast(y)][@intCast(z)][1];
            }
        }
    } else if (!on_x_any_edge and on_y_any_edge and !on_z_any_edge) {
        if (x == -1) {
            if (chunk_data.neighbours[2]) |neighbour| {
                return neighbour.blocks[Chunk.chunk_length - 1][@intCast(z)][@intCast(x)];
            }
        } else {
            if (chunk_data.neighbours[3]) |neighbour| {
                return neighbour.blocks[1][@intCast(z)][@intCast(x)];
            }
        }
    } else if (!on_x_any_edge and !on_y_any_edge and on_z_any_edge) {
        if (x == -1) {
            if (chunk_data.neighbours[4]) |neighbour| {
                return neighbour.blocks[@intCast(y)][Chunk.chunk_length - 1][@intCast(x)];
            }
        } else {
            if (chunk_data.neighbours[5]) |neighbour| {
                return neighbour.blocks[@intCast(y)][1][@intCast(x)];
            }
        }
    } else if (!on_x_any_edge and !on_y_any_edge and !on_z_any_edge) {
        return chunk_data.blocks[@intCast(y)][@intCast(z)][@intCast(x)];
    }

    return null;
}
