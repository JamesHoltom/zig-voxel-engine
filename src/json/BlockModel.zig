const std = @import("std");

pub const BlockModel = struct {
    id: []const u8,
    name: []const u8,
    faces: [6]Face,

    const Face = struct {
        vertices: [][3]f32,
        elements: [][3]u32,
        normal: [3]f32,
    };

    pub fn readFromJson(allocator: std.mem.Allocator, file_name: []const u8) !BlockModel {
        const model_file = try std.fs.cwd().openFile(file_name, .{ .mode = .read_only });
        defer model_file.close();

        var model_buffer: [4096]u8 = undefined;
        var buffered_reader = std.io.bufferedReader(model_file.reader());
        const length = try buffered_reader.reader().readAll(&model_buffer);

        const parsedBlockModel = try std.json.parseFromSlice(BlockModel, allocator, model_buffer[0..length], .{});

        return parsedBlockModel.value;
    }
};
