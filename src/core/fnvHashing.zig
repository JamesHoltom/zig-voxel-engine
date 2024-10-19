//! This file provides an implementation for the non-cryptographic [Fowler-Noll-Vo](https://en.wikipedia.org/wiki/Fowler%E2%80%93Noll%E2%80%93Vo_hash_function) hashing function.
//! Both the FNV-1 and FNV-1a hashing functions are implemented.
//! One difference between this implementation and the

const std = @import("std");

pub const HashError = error{
    InvalidType,
};

/// Returns a prime number that is used to transform the hash value during execution.
/// Different prime numbers offer different levels of dispersion quality and compiler optimisation.
fn getPrime(comptime T: type) HashError!T {
    return switch (T) {
        u32 => 16777619,
        u64 => 1099511628211,
        u128 => 309485009821345068724781371,
        else => HashError.InvalidType,
    };
}

/// Generates a hash offset that is used as the starting value for other hashes.
/// This emulates the [FNV-0](https://en.wikipedia.org/wiki/Fowler%E2%80%93Noll%E2%80%93Vo_hash_function#FNV-0_hash_(deprecated)) hashing function, which uses 0 as a hash offset and is recommended only for this use.
pub fn generateHashOffset(comptime T: type, seed: []const u8) HashError!T {
    return fnv1Hash(T, seed, 0);
}

pub fn fnv1Hash(comptime T: type, str: []const u8, hash_offset: T) HashError!T {
    const prime = try getPrime(T);
    var hash: T = hash_offset;

    for (str) |char| {
        hash *%= prime;
        hash ^= char;
    }

    return hash;
}

pub fn fnv1aHash(comptime T: type, str: []const u8, hash_offset: T) HashError!T {
    const prime = try getPrime(T);
    var hash: T = hash_offset;

    for (str) |char| {
        hash ^= char;
        hash *%= prime;
    }

    return hash;
}

test generateHashOffset {
    const expected: u32 = 1993788104;
    const actual = try generateHashOffset(u32, "Zig Voxel Engine test +*--##--*+");

    try std.testing.expectEqual(expected, actual);
}

test fnv1Hash {
    const hash_offset = try generateHashOffset(u32, "Zig Voxel Engine test +*--##--*+");
    const expected: u32 = 3506898347;
    const actual = fnv1Hash(u32, "Example string data", hash_offset);

    try std.testing.expectEqual(expected, actual);
}

test fnv1aHash {
    const hash_offset = try generateHashOffset(u32, "Zig Voxel Engine test +*--##--*+");
    const expected: u32 = 955373121;
    const actual = fnv1aHash(u32, "Example string data", hash_offset);

    try std.testing.expectEqual(expected, actual);
}
