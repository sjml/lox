// adapting from linenoize
// https://github.com/joachimschmidt557/linenoize/blob/master/src/term.zig

const std = @import("std");
const File = std.fs.File;
const Allocator = std.mem.Allocator;

const KEY_CTRL_C = 3;
const KEY_CTRL_D = 4;
const KEY_ENTER = 13;

pub const TermError = error{
    SIGINT,
    EOF,
    UNKNOWN,
};

pub fn enableRawMode(in: File) !std.posix.termios {
    const orig = try std.posix.tcgetattr(in.handle);
    var raw = orig;

    raw.iflag.BRKINT = false;
    raw.iflag.ICRNL = false;
    raw.iflag.INPCK = false;
    raw.iflag.ISTRIP = false;
    raw.iflag.IXON = false;

    raw.oflag.OPOST = false;

    raw.cflag.CSIZE = .CS8;

    raw.lflag.ECHO = false;
    raw.lflag.ICANON = false;
    raw.lflag.IEXTEN = false;
    raw.lflag.ISIG = false;

    try std.posix.tcsetattr(in.handle, std.posix.TCSA.FLUSH, raw);
    return orig;
}

pub fn disableRawMode(in: File, orig: std.posix.termios) void {
    std.posix.tcsetattr(in.handle, std.posix.TCSA.FLUSH, orig) catch {};
}

pub fn getLine(allocator: Allocator, in: File, out: File, prompt: []const u8) ![]const u8 {
    _ = try out.write(prompt);
    var line_buf: [1024]u8 = undefined;
    var line_pos: usize = 0;

    while (true) {
        var input_buf: [1]u8 = undefined;
        if ((try in.read(&input_buf)) < 1) {
            return TermError.UNKNOWN;
        }

        switch (input_buf[0]) {
            KEY_CTRL_C => {
                return TermError.SIGINT;
            },
            KEY_CTRL_D => {
                if (line_pos == 0) {
                    return TermError.EOF;
                } else {
                    continue;
                }
            },
            KEY_ENTER => {
                const line = try allocator.dupe(u8, line_buf[0..line_pos]);
                return line;
            },
            else => {
                _ = try out.write(input_buf[0..]);
                line_buf[line_pos] = input_buf[0];
                line_pos += 1;
                // var utf8_buf: [4]u8 = undefined;
                // const utf8_len = std.unicode.utf8ByteSequenceLength(c) catch continue;
                // utf8_buf[0] = c;
                // if (utf8_len > 1 and (try in.read(utf8_buf[1..utf8_len])) < utf8_len - 1) return null;
            },
        }
    }
}
