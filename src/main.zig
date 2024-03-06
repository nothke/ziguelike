const std = @import("std");
const c = @cImport({
    @cInclude("conio.h");
});

const Coord = struct {
    x: i32,
    y: i32,
};

const zero = Coord{ .x = 0, .y = 0 };

const Player = struct {
    pos: Coord,
};

const TileType = enum {
    Air,
    Wall,
};

const Tile = struct {
    pos: Coord = .{ .x = 0, .y = 0 },
    tileType: TileType = .Air,
};

const width: i32 = 30;
const height: i32 = 10;

fn toIndex(pos: Coord) u32 {
    return @intCast(pos.y * width + pos.x);
}

fn toIndexXY(x: i32, y: i32) u32 {
    return @intCast(y * width + x);
}

fn toCoord(i: u32) Coord {
    return Coord{
        .x = @intCast(i % width),
        .y = @intCast(@divFloor(i, width)),
    };
}

fn placeRoom(world: []Tile, x: i32, y: i32, w: i32, h: i32) void {
    for (0..@intCast(w)) |xi| {
        for (0..@intCast(h)) |yi| {
            const xi32: i32 = @intCast(xi);
            const yi32: i32 = @intCast(yi);
            world[toIndexXY(x + xi32, y + yi32)].tileType = .Air;
        }
    }
}

pub fn main() !void {
    const stdout_file = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout_file);
    const stdout = bw.writer();

    var screen = [_]u8{'.'} ** (width * height);
    screen[0] = '#';

    var world = [_]Tile{.{ .tileType = .Wall }} ** (width * height);

    for (&world, 0..world.len) |*tile, i| {
        tile.pos = toCoord(@intCast(i));
        //try stdout.print("index: {}, coord x: {}, y: {}\n", .{ i, tile.pos.x, tile.pos.y });
    }

    placeRoom(&world, 2, 2, 6, 6);
    placeRoom(&world, 10, 2, 12, 6);
    placeRoom(&world, 5, 5, 5, 1);

    world[toIndexXY(5, 5)].tileType = .Wall;

    // for (0..6) |i| {
    //     world[toIndexXY(@intCast(i + 10), 6)].tileType = .Wall;
    // }

    var player = Player{
        .pos = .{ .x = 3, .y = 3 },
    };

    // #LOOP
    while (true) {
        //@memset(&screen, '.');

        for (world, &screen) |tile, *pixel| {
            pixel.* = if (tile.tileType == .Air) '.' else '#';
        }

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

        var desiredMove = zero;

        switch (input) {
            'a' => desiredMove.x = -1,
            'd' => desiredMove.x = 1,
            'w' => desiredMove.y = -1,
            's' => desiredMove.y = 1,
            'q' => break,
            else => {},
        }

        const targetCoord = Coord{
            .x = player.pos.x + desiredMove.x,
            .y = player.pos.y + desiredMove.y,
        };

        if (world[toIndex(targetCoord)].tileType == .Air) {
            player.pos = targetCoord;
        }
    }
}
