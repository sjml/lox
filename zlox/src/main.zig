const std = @import("std");
const Allocator = std.mem.Allocator;

const util = @import("./util.zig");
const vm = @import("./vm.zig");
const VM = vm.VM;
const term = @import("./term.zig");
const compiler = @import("./compiler.zig");

pub fn repl(allocator: Allocator) !void {
    const stdin_file = std.io.getStdIn();
    const stdout_file = std.io.getStdOut();
    defer stdout_file.writeAll("\n") catch {};

    const orig = try term.enableRawMode(stdin_file);
    defer term.disableRawMode(stdin_file, orig);

    while (true) {
        const line = term.getLine(allocator, stdin_file, stdout_file, "> ") catch |err| switch (err) {
            error.SIGINT => {
                _ = try stdout_file.write("^C\r\n");
                continue;
            },
            error.EOF => {
                _ = try stdout_file.write("^D\r\n");
                break;
            },
            error.UNKNOWN => {
                _ = try stdout_file.write("ERROR: Unknown input sequence.");
                break;
            },
            else => {
                break;
            },
        };
        defer allocator.free(line);

        _ = try stdout_file.write("\r\n");

        _ = try stdout_file.write(line);
        _ = try stdout_file.write("\r\n");
    }
}

pub const RunFileError = error{
    COULD_NOT_OPEN,
    OUT_OF_MEMORY,
    COULD_NOT_READ,
};

pub fn runFile(allocator: Allocator, path: []u8) !vm.InterpretResult {
    var file = std.fs.cwd().openFile(path, .{}) catch {
        try util.printf("Could not open file `{s}`\n", .{path});
        return error.COULD_NOT_OPEN;
    };
    const file_size = (file.stat() catch {
        try util.printf("Could not read filesize of `{s}`\n", .{path});
        return error.COULD_NOT_READ;
    }).size;
    const file_buffer = allocator.alloc(u8, file_size + 1) catch {
        try util.printf("Out of memory; could not load `{s}`\n", .{path});
        return error.OUT_OF_MEMORY;
    };
    defer allocator.free(file_buffer);
    _ = file.reader().read(file_buffer) catch {
        try util.printf("Could not read `{s}`\n", .{path});
        return error.COULD_NOT_READ;
    };
    file_buffer[file_size] = 0;

    const res = vm.VM.interpret(file_buffer);

    return res;
}

pub fn main() !u8 {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    VM.setup(allocator);
    defer VM.teardown();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len == 1) {
        try repl(allocator);
        return 0;
    } else if (args.len == 2) {
        const res = runFile(allocator, args[1]) catch |err| switch (err) {
            RunFileError.COULD_NOT_OPEN => {
                return 74;
            },
            RunFileError.COULD_NOT_READ => {
                return 74;
            },
            RunFileError.OUT_OF_MEMORY => {
                return 74;
            },
            else => {
                return 1;
            },
        };
        switch (res) {
            vm.InterpretResult.INTERPRET_COMPILE_ERROR => {
                return 65;
            },
            vm.InterpretResult.INTERPRET_RUNTIME_ERROR => {
                return 70;
            },
            vm.InterpretResult.INTERPRET_OK => {
                return 0;
            },
        }
    } else {
        try util.printf("Usage: zlox [path]\n", .{});
        return 64;
    }

    // return 0;
}
