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
    item: Item = .empty,
};

const Key = struct {
    keyType: u8,
};

const Door = struct {
    keyType: u8,
    isOpen: bool,
};

const Item = union(enum) {
    empty,
    key: Key,
    door: Door,

    fn getSymbol(self: Item) u8 {
        return switch (self) {
            .key => 'f',
            .door => if (self.door.isOpen) '\'' else 'D',
            else => unreachable,
        };
    }
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

    world[toIndexXY(2, 2)].item = .{ .key = .{ .keyType = 1 } };
    world[toIndexXY(3, 2)].item = .{ .key = .{ .keyType = 1 } };
    world[toIndexXY(9, 5)].item = .{ .door = .{ .keyType = 1, .isOpen = false } };

    // for (0..6) |i| {
    //     world[toIndexXY(@intCast(i + 10), 6)].tileType = .Wall;
    // }

    var player = Player{
        .pos = .{ .x = 3, .y = 3 },
    };

    var heldItem: ?Item = null;

    // #LOOP
    while (true) {
        //@memset(&screen, '.');

        // Drawing
        for (world, &screen) |tile, *pixel| {
            pixel.* = if (tile.tileType == .Air) '.' else '#';

            if (tile.item != .empty) {
                pixel.* = tile.item.getSymbol();
            }
        }

        screen[toIndex(player.pos)] = '@';

        try stdout.print("\x1B[2J\x1B[H", .{});

        for (0..height) |y| {
            try stdout.print("\n", .{});
            for (0..width) |x| {
                try stdout.print("{c}", .{screen[y * width + x]});
            }
        }

        try stdout.print("\n\nplayer: {}, {}", .{ player.pos.x, player.pos.y });

        const playerTile = world[toIndex(player.pos)];

        var itemToTake: ?Item = null;

        if (playerTile.item != .empty) {
            switch (playerTile.item) {
                .key => |key| {
                    try stdout.print("\nkey: {}, press space to take", .{key.keyType});
                    itemToTake = playerTile.item;
                },
                else => {},
            }
        }

        if (heldItem) |item| {
            try stdout.print("\nHeld: {c}", .{item.getSymbol()});
        }

        var doorTile: ?*Tile = null;

        if (heldItem) |item| {
            if (item == .key) {
                for (@intCast(player.pos.x - 1)..@intCast(player.pos.x + 2)) |x| {
                    const tile = &world[toIndexXY(@intCast(x), player.pos.y)];
                    if (tile.item == .door) {
                        doorTile = tile;
                        //doorToUnlock = tile.item.door;
                        try stdout.print("\nCan unlock door\n", .{});
                        break;
                    }
                }
            }
        }

        try bw.flush();

        const input: i32 = c.getch();

        //try stdout.print("\n ------------------------- \n", .{});

        var desiredMove = zero;

        switch (input) {
            'a' => desiredMove.x = -1,
            'd' => desiredMove.x = 1,
            'w' => desiredMove.y = -1,
            's' => desiredMove.y = 1,
            ' ' => {
                if (itemToTake) |item| {
                    if (heldItem == null) {
                        heldItem = item;
                        world[toIndex(player.pos)].item = .empty;
                    }
                } else {
                    if (doorTile) |doorTilePtr| {
                        doorTilePtr.item.door.isOpen = !doorTilePtr.item.door.isOpen;
                    }
                }
            },
            'e' => {
                if (heldItem) |item| {
                    if (itemToTake == null) {
                        world[toIndex(player.pos)].item = item;
                        heldItem = null;
                    }
                }
            },
            'q' => break,
            else => {},
        }

        const targetCoord = Coord{
            .x = player.pos.x + desiredMove.x,
            .y = player.pos.y + desiredMove.y,
        };

        const targetTile = &world[toIndex(targetCoord)];
        const doorExistsAndIsClosed = targetTile.item == .door and !targetTile.item.door.isOpen;

        if (targetTile.tileType == .Air and !doorExistsAndIsClosed) {
            player.pos = targetCoord;
        }
    }
}
