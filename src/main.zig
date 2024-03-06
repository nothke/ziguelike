const std = @import("std");
const c = @cImport({
    @cInclude("conio.h");
});

const Coord = struct {
    x: i32,
    y: i32,
};

const Player = struct {
    pos: Coord,
};

const width: i32 = 30;
const height: i32 = 10;

fn toIndex(pos: Coord) u32 {
    return @intCast(pos.y * width + pos.x);
}

pub fn main() !void {
    const stdout_file = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout_file);
    const stdout = bw.writer();

    var screen = [_]u8{'.'} ** (width * height);
    screen[0] = '#';

    var player = Player{
        .pos = .{ .x = 3, .y = 3 },
    };

    while (true) {
        @memset(&screen, '.');

        screen[toIndex(player.pos)] = '@';

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
            'a' => player.pos.x -= 1,
            'd' => player.pos.x += 1,
            'w' => player.pos.y -= 1,
            's' => player.pos.y += 1,
            'q' => break,
            else => {},
        }
    }
}
