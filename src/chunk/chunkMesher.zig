const std = @import("std");
const gl = @import("zopengl").bindings;
const Chunk = @import("Chunk.zig").Chunk;
const chunk_buffer = @import("chunkBuffer.zig");
const Block = @import("../block/Block.zig").Block;
const buffers = @import("../gl/bufferObjects.zig");

pub const MeshData = struct {
    data: [256]u32,
    offsets: [6][2]u32,
    count: usize,
};
const SolidMaskData = [3][padded_chunk_length][padded_chunk_length]u64;
const EdgeMaskData = [6][Chunk.chunk_length][Chunk.chunk_length]u32;

const padded_chunk_length: comptime_int = Chunk.chunk_length + 2;

pub fn createChunkMeshes(chunk_data: *const Chunk) MeshData {
    var solid_mask_data = std.mem.zeroes(SolidMaskData);
    var edge_mask_data = std.mem.zeroes(EdgeMaskData);
    var x: isize = undefined;
    var y: isize = undefined;
    var z: isize = -1;

    // Part 1: Generate the mask data for solid voxels on each face.
    while (z < padded_chunk_length - 1) : (z += 1) {
        y = -1;

        while (y < padded_chunk_length - 1) : (y += 1) {
            x = -1;

            while (x < padded_chunk_length - 1) : (x += 1) {
                const block = getWorldToSampleBlock(chunk_data, x, y, z) orelse Block.air();

                if (block.material_type == 1) {
                    std.log.debug("Got block of type {d} at position {d},{d},{d}", .{ block.material_type, x, y, z });

                    // For the east/west faces, generate the mask data on:
                    //   * The Y layer.
                    //   * The Z column.
                    //   * The X row.
                    solid_mask_data[0][@intCast(y + 1)][@intCast(z + 1)] |= @as(u64, 1) << @as(u6, @intCast(x + 1));

                    // For the top/bottom faces, generate the mask data on:
                    //   * The Z layer.
                    //   * The X column.
                    //   * The Y row.
                    solid_mask_data[1][@intCast(z + 1)][@intCast(x + 1)] |= @as(u64, 1) << @as(u6, @intCast(y + 1));

                    // For the north/south faces, generate the mask data on:
                    //   * The Y layer.
                    //   * The X column.
                    //   * The Z row.
                    solid_mask_data[2][@intCast(y + 1)][@intCast(x + 1)] |= @as(u64, 1) << @as(u6, @intCast(z + 1));
                }
            }
        }
    }

    // Part 2: Generate the mask data for voxels with a renderable face on each axis.
    var face: usize = 0;

    while (face < 3) : (face += 1) {
        for (1..padded_chunk_length - 1) |layer| {
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
                const row = solid_mask_data[face][layer][column];

                if (row != 0) {
                    const positive_mask: u64 = row & ~(row >> 1);
                    const negative_mask: u64 = row & ~(row << 1);

                    edge_mask_data[face * 2][layer - 1][column - 1] = @truncate(positive_mask >> 1);
                    edge_mask_data[(face * 2) + 1][layer - 1][column - 1] = @truncate(negative_mask >> 1);

                    std.debug.print("Face {d}\nBefore: {b:0>34}\nLeft:    {b:0>32}\nRight:   {b:0>32}\n", .{
                        face,
                        row,
                        edge_mask_data[face * 2][layer - 1][column - 1],
                        edge_mask_data[(face * 2) + 1][layer - 1][column - 1],
                    });
                }
            }
        }
    }

    // Part 3: Convert the mask data into meshes to insert into the data lists.
    var start_bound: usize = 0;
    var mesh_count: usize = 0;
    var mesh_data: MeshData = .{
        .data = undefined,
        .offsets = undefined,
        .count = 0,
    };

    face = 0;

    while (face < 6) : (face += 1) {
        for (0..Chunk.chunk_length) |layer| {
            for (0..Chunk.chunk_length) |column| {
                var row: u32 = 0;

                while (row < Chunk.chunk_length) : (row += 1) {
                    // Step 1: Find the row offset to the next edge bit.
                    // This is done by counting the number of trailing zeros.
                    // E.g. @ctz(0b01111000) will return 3.
                    const offset: u32 = @ctz(edge_mask_data[face][layer][column] >> @as(u5, @intCast(row)));
                    row += offset;

                    // If we've reached the start of the row, break out of the loop.
                    if (row >= Chunk.chunk_length) {
                        if (face == 0 and layer < 2 and column < 2) {
                            std.debug.print("Face {d: >2}, Layer {d: >2}, Column {d: >2}, EOR\n", .{ face, layer, column });
                        }
                        break;
                    }

                    // Step 2: Calculate the width of the mesh.
                    // This is done by offseting the mask data by the offset in step 1, then counting the number of trailing ones.
                    // E.g. @ctz(~(0b01111000 >> 3)) will return 4.
                    const width: u32 = @ctz(~(edge_mask_data[face][layer][column] >> @as(u5, @intCast(row))));

                    // Step 3: Generate a mask from the offset and width, to compare against other columns.
                    const width_mask: u32 = ((@as(u32, 1) << @as(u5, @intCast(width))) - 1) << @as(u5, @intCast(row));

                    var height: u32 = 1;
                    var next_column = column + 1;

                    while (next_column < Chunk.chunk_length) : (next_column += 1) {
                        const row_mask = edge_mask_data[face][layer][next_column];

                        // Step 4: Remove the bits from the edge mask data, so they do not get counted towards other meshes.
                        edge_mask_data[face][layer][next_column] &= ~width_mask;

                        // Step 5: If the next column does not match the mask from step 3, break out of the loop.
                        if (row_mask & width_mask != width_mask) {
                            break;
                        } else {
                            height += 1;
                        }
                    }

                    std.log.debug("F: {d}, W: {d}, H: {d}", .{ face, width, height });

                    // Step 6: Append the mesh data to the list.
                    const value: u32 = switch (face) {
                        0, 1 => row | (@as(u32, @intCast(layer)) << 5) | (@as(u32, @intCast(column)) << 10) | (width << 15) | (height << 20),
                        2, 3 => @as(u32, @intCast(column)) | (row << 5) | (@as(u32, @intCast(layer)) << 10) | (width << 15) | (height << 20),
                        4, 5 => @as(u32, @intCast(column)) | (@as(u32, @intCast(layer)) << 5) | (row << 10) | (height << 15) | (width << 20),
                        else => unreachable,
                    };
                    mesh_data.data[mesh_count] = value;

                    std.log.debug("Index: {d: >2}, Value: {b:0>32}", .{ mesh_count, value });

                    mesh_count += 1;
                }
            }
        }

        // Step 7: At the end of each face, calculate the boundaries of the data, to compile indirect GPU commands with.
        // mesh_data.draw_commands[face] = gl.DrawArraysIndirectCommand{
        //     .count = 4,
        //     .instance_count = @intCast(mesh_count - start_bound),
        //     .first = 0,
        //     .base_instance = @intCast(start_bound),
        // };
        std.log.debug("Start Index: {d}, Count: {d}", .{ start_bound, mesh_count });
        mesh_data.offsets[face][0] = @intCast(start_bound);
        mesh_data.offsets[face][0] = @intCast(mesh_count);
        start_bound = mesh_count;
    }

    std.log.debug("Reduced to {d} meshes.", .{start_bound});
    mesh_data.count = mesh_count;

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
