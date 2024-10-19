const std = @import("std");
const stbi = @import("zstbi");

pub const TextureLoader = struct {
    pub fn loadFromFile(allocator: std.mem.Allocator, file_name: [:0]const u8) !stbi.Image {
        const image_file: [1][]const u8 = .{try std.fs.cwd().realpathAlloc(allocator, file_name)};
        const img_sen: [:0]u8 = try std.mem.concatWithSentinel(allocator, u8, &image_file, 0);
        defer allocator.free(img_sen);
        defer allocator.free(image_file[0]);

        return stbi.Image.loadFromFile(img_sen, 0);
    }
};
