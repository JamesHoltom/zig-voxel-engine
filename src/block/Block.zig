pub const BlockRotation = enum {
    Up,
    Down,
    North,
    South,
    East,
    West,
};

pub const Block = struct {
    material_type: u32,
    rotation: BlockRotation,

    const air_block = Block{
        .material_type = 0,
        .rotation = BlockRotation.Up,
    };

    pub fn init(block_type: u32) Block {
        return Block{
            .material_type = block_type,
            .rotation = BlockRotation.Up,
        };
    }

    pub inline fn air() Block {
        return air_block;
    }
};
