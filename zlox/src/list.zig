// Shane, doesn't Zig have built-in stuff for this?
//  Yes, but the point is to do as much low-level stuff as possible.
const std = @import("std");
const Allocator = std.mem.Allocator;

const memory = @import("./memory.zig");

pub fn List(comptime T: type) type {
    return struct {
        count: usize = 0,
        allocator: Allocator,
        items: []T,

        pub fn init(allocator: Allocator) !List(T) {
            return List(T){
                .allocator = allocator,
                .items = &[_]T{},
            };
        }

        pub fn deinit(self: *List(T)) void {
            if (self.count > 0) {
                self.allocator.free(self.items);
            }
        }

        pub fn add(self: *List(T), element: T) void {
            if (self.items.len < self.count + 1) {
                const new_capacity = memory.growCapacity(self.items.len);
                self.items = self.allocator.realloc(self.items, new_capacity) catch @panic("Error reallocating memory.");
            }
            self.items[self.count] = element;
            self.count += 1;
        }

        pub fn free(self: *List(T)) void {
            self.items = self.allocator.realloc(self.items, 0) catch @panic("Error reallocating memory.");
            self.count = 0;
        }
    };
}

test "setup and teardown list without leaking" {
    const allocator = std.testing.allocator;
    const ByteList = List(u8);
    var bl = try ByteList.init(allocator);
    bl.deinit();
}

test "adding to list" {
    const allocator = std.testing.allocator;
    const ByteList = List(u8);
    var bl = try ByteList.init(allocator);
    try std.testing.expect(bl.count == 0);
    bl.add(123);
    try std.testing.expect(bl.count == 1);
    try std.testing.expect(bl.items[0] == 123);
    bl.deinit();
}

test "multiple list adds" {
    const allocator = std.testing.allocator;
    const ByteList = List(u8);
    var bl = try ByteList.init(allocator);
    bl.add(0);
    bl.add(1);
    bl.add(2);
    bl.add(3);
    bl.add(4);
    bl.add(5);
    bl.add(6);
    bl.add(7);
    bl.add(8);
    bl.add(9);
    bl.add(10);
    bl.add(11);
    bl.add(12);
    try std.testing.expect(bl.items.len == 16);
    try std.testing.expect(bl.items[9] == 9);
    try std.testing.expect(bl.count == 13);
    bl.deinit();
}

test "freeing list" {
    const allocator = std.testing.allocator;
    const ByteList = List(u8);
    var bl = try ByteList.init(allocator);
    bl.add(0);
    bl.add(1);
    bl.add(2);
    bl.add(3);
    bl.add(4);
    bl.add(5);
    bl.add(6);
    bl.add(7);
    bl.add(8);
    bl.add(9);
    bl.add(10);
    bl.add(11);
    bl.add(12);

    bl.free();
    try std.testing.expect(bl.count == 0);
    try std.testing.expect(bl.items.len == 0);

    bl.deinit();
}

test "playing" {
    const allocator = std.testing.allocator;
    const datums = try allocator.alloc(u8, 4);
    var ptr: [*]u8 = datums.ptr;

    ptr[0] = 1;
    ptr += 1;
    ptr[0] = 2;
    ptr += 1;
    ptr[0] = 3;
    // const testVal = &ptr[0];
    // std.debug.print("addr: {d}; val: {d}\n", .{ testVal, testVal.* });
    ptr += 1;
    ptr[0] = 4;
    allocator.free(datums);
}

// test "pointer arithmetic" {
//     const allocator = std.testing.allocator;
//     const ByteList = List(u8);
//     var bl = try ByteList.init(allocator);
//     bl.add(0);
//     bl.add(1);
//     bl.add(2);
//     bl.add(3);
//     bl.add(4);
//     bl.add(5);
//     bl.add(6);
//     bl.add(7);
//     bl.add(8);
//     bl.add(9);
//     bl.add(10);
//     bl.add(11);
//     bl.add(12);

//     var ip = bl.items.ptr[0..];
//     try std.testing.expect(ip[0] == 0);
//     ip += 3;
//     try std.testing.expect(ip[0] == 3);

//     bl.deinit();
// }
