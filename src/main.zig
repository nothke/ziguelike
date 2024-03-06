const std = @import("std");
const c = @cImport({
    @cInclude("conio.h");
});

pub fn main() !void {
    std.debug.print("All your {s} are belong to us.\n", .{"codebase"});

    const stdout_file = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout_file);
    const stdout = bw.writer();

    const stdin = std.io.getStdIn().reader();
    _ = stdin; // autofix

    try stdout.print("Run `zig build test` to run the tests.", .{});
    try stdout.print("Run `zig build test` to run the tests.\n", .{});

    const width: i32 = 30;
    const height: i32 = 10;

    var screen = [_]u8{'.'} ** (width * height);
    screen[0] = '#';

    var playerX: i32 = 3;
    var playerY: i32 = 3;

    while (true) {
        screen = [_]u8{'.'} ** (width * height);

        screen[@intCast(playerY * width + playerX)] = '@';

        for (0..height) |y| {
            try stdout.print("\n", .{});
            for (0..width) |x| {
                try stdout.print("{c}", .{screen[y * width + x]});
            }
        }

        try bw.flush();

        const input: i32 = c.getch();

        try stdout.writeByteNTimes('\n', 30);

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

test "simple test" {
    var list = std.ArrayList(i32).init(std.testing.allocator);
    defer list.deinit(); // try commenting this out and see if zig detects the memory leak!
    try list.append(42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}
