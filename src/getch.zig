const std = @import("std");
const builtin = @import("builtin");

// Get a keypress. This works for Linux.
// Source: https://viewsourcecode.org/snaptoken/kilo/02.enteringRawMode.html
// TODO: simple Zig package for getch (at least for Linux and Windows)
fn getch_linux() !u8 {
    const stdin = std.io.getStdIn().reader();
    const c = @cImport({
        @cInclude("termios.h");
        @cInclude("unistd.h");
    });

    // save current mode
    var orig_termios: c.termios = undefined;
    _ = c.tcgetattr(c.STDIN_FILENO, &orig_termios);

    // set new "raw" mode
    var raw = orig_termios;
    raw.c_lflag &= @bitCast(~(c.ECHO | c.ICANON | c.ISIG));
    _ = c.tcsetattr(c.STDIN_FILENO, c.TCSAFLUSH, &raw);

    const char = try stdin.readByte();

    // restore old mode
    _ = c.tcsetattr(c.STDIN_FILENO, c.TCSAFLUSH, &orig_termios);
    return char;
}

// Get a keypress. This works for Windows.
fn getch_win() !u8 {
    const c = @cImport({
        @cInclude("conio.h");
    });

    const char = c.getch();
    return @as(u8, @truncate(@as(u32, @bitCast(char))));
}

pub const getch = if (builtin.os.tag == .windows) getch_win else getch_linux;
