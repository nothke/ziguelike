const std = @import("std");
const c = @cImport({
    @cInclude("conio.h");
});

pub fn main() !void {
    const stdout_file = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout_file);
    const stdout = bw.writer();

    const width: i32 = 30;
    const height: i32 = 10;

    var screen = [_]u8{'.'} ** (width * height);
    screen[0] = '#';

    var playerX: i32 = 3;
    var playerY: i32 = 3;

    while (true) {
        @memset(&screen, '.');

        screen[@intCast(playerY * width + playerX)] = '@';

        try stdout.print("\x1B[2J\x1B[H", .{});

        for (0..height) |y| {
            try stdout.print("\n", .{});
            for (0..width) |x| {
                try stdout.print("{c}", .{screen[y * width + x]});
            }
        }

        try bw.flush();

        const input: i32 = c.getch();

        try stdout.print("\n ------------------------- \n", .{});

        switch (input) {
            'a' => playerX -= 1,
            'd' => playerX += 1,
            'w' => playerY -= 1,
            's' => playerY += 1,
            'q' => break,
            else => {},
        }
    }
}
