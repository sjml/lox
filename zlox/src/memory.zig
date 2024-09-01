const std = @import("std");
const Allocator = std.mem.Allocator;

pub fn growCapacity(old_cap: usize) usize {
    return if (old_cap < 8) 8 else old_cap * 2;
}

// pub fn freeArray(comptime T: type, allocator: Allocator, arr: []T) !void {
//     _ = try reallocate(T, allocator, arr, 0);
// }

// pub fn reallocate(comptime T: type, allocator: Allocator, pointer: []T, new_size: usize) ![]T {
//     return try allocator.realloc(pointer, new_size);
// }
