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

    while (true) {
        for (0..10) |_| {
            try stdout.print("\n", .{});
            for (0..30) |_| {
                try stdout.print("#", .{});
            }
        }

        try bw.flush();

        const input: i32 = c.getch();

        try stdout.print("\n ------------------------- \n", .{});

        if (input == 'q')
            break;
    }
}

test "simple test" {
    var list = std.ArrayList(i32).init(std.testing.allocator);
    defer list.deinit(); // try commenting this out and see if zig detects the memory leak!
    try list.append(42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}
