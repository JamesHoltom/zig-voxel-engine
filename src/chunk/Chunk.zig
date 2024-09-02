const std = @import("std");
const Block = @import("../block/Block.zig").Block;

/// Blocks are stored in YZX format, for more effective compression (down the line).
pub const Chunk = struct {
    blocks: BlockMap,
    neighbours: [6]?*Chunk,
    position: [3]i64,

    pub const chunk_length: comptime_int = 32;
    pub const chunk_area: comptime_int = chunk_length ^ 2;
    pub const chunk_volume: comptime_int = chunk_length ^ 3;

    pub const BlockMap = [chunk_length][chunk_length][chunk_length]Block;

    pub fn create(position: [3]i64) Chunk {
        return Chunk{
            .position = position,
            .blocks = std.mem.zeroes(BlockMap),
            .neighbours = [6]?*Chunk{ null, null, null, null, null, null },
        };
    }
};
