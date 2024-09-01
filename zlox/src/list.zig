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

        pub fn deinit(self: *List(T)) !void {
            if (self.count > 0) {
                self.allocator.free(self.items);
            }
        }

        pub fn add(self: *List(T), element: T) void {
            if (self.items.len < self.count + 1) {
                const new_capacity = memory.growCapacity(self.items.len);
                self.items = self.allocator.realloc(self.items, new_capacity) catch @panic("Error allocating new memory.");
            }
            self.items[self.count] = element;
            self.count += 1;
        }

        pub fn free(self: *List(T)) !void {
            // self.contents = try self.allocator.realloc(self.contents, 0);
            self.count = 0;
        }
    };
}
