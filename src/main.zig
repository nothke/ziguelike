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
    item: ?Item = null,
};

const Key = struct {
    keyType: u8,
};

const Door = struct {
    keyType: u8,
    isOpen: bool,
};

const Info = struct {
    message: []const u8,
};

const Item = union(enum) {
    key: Key,
    door: Door,
    info: Info,

    fn getSymbol(self: Item) u8 {
        return switch (self) {
            .key => 'f',
            .door => if (self.door.isOpen) '\'' else 'D',
            .info => '?',
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
    world[toIndexXY(5, 7)].item = .{ .key = .{ .keyType = 1 } };
    world[toIndexXY(9, 5)].item = .{ .door = .{ .keyType = 1, .isOpen = false } };

    world[toIndexXY(2, 3)].item = .{ .info = .{ .message = "Hello world!" } };
    world[toIndexXY(2, 4)].item = .{ .info = .{ .message = "Welcome to the dungeon!!" } };
    world[toIndexXY(2, 6)].item = .{ .info = .{ .message = "This is a very scary, very scary dungeon!!!" } };

    // for (0..6) |i| {
    //     world[toIndexXY(@intCast(i + 10), 6)].tileType = .Wall;
    // }

    var player = Player{ .pos = .{ .x = 3, .y = 3 } };

    var heldItem: ?Item = null;

    var lastTyped: u8 = ' ';

    // #LOOP
    while (true) {
        //@memset(&screen, '.');

        // Drawing
        for (world, &screen) |tile, *pixel| {
            pixel.* = if (tile.tileType == .Air) '.' else '#';

            if (tile.item) |item| {
                pixel.* = item.getSymbol();
            }
        }

        screen[toIndex(player.pos)] = '@';

        // Clear screen
        try stdout.print("\x1B[2J\x1B[3J\x1B[H", .{});

        for (0..height) |y| {
            try stdout.print("\n", .{});
            for (0..width) |x| {
                try stdout.print("{c}", .{screen[y * width + x]});
            }
        }

        try stdout.print("\n", .{});

        const playerTile = world[toIndex(player.pos)];

        var itemToTake: ?Item = null;

        if (playerTile.item) |playerTileItem| {
            switch (playerTileItem) {
                .key => |key| {
                    try stdout.print("\nkey: {}, press space to take", .{key.keyType});
                    itemToTake = playerTileItem;
                },
                .info => |info| try stdout.print("\nMessage: {s}", .{info.message}),
                else => {},
            }
        }

        if (heldItem) |item| {
            try stdout.print("\nHeld: {c}", .{item.getSymbol()});
        }

        var doorTile: ?*Tile = null;

        if (heldItem) |item| {
            if (item == .key) {
                var y: i32 = player.pos.y - 1;
                while (y <= player.pos.y + 1) : (y += 1) {
                    var x: i32 = player.pos.x - 1;
                    while (x <= player.pos.x + 1) : (x += 1) {
                        const tile = &world[toIndexXY(x, y)];

                        if (tile.item) |tileItem| {
                            if (tileItem == .door) {
                                doorTile = tile;
                                //doorToUnlock = tile.item.door;
                                const lockText = if (tileItem.door.isOpen) "lock" else "unlock";
                                try stdout.print("\nSpace to {sd} door\n", .{lockText});
                                break;
                            }
                        }
                    }
                }
            }
        }

        // Debug
        try stdout.print("\n\nDebug:", .{});
        try stdout.print("\n- player pos: {}, {}", .{ player.pos.x, player.pos.y });
        try stdout.print("\n- last typed: code: '{}' char: '{c}'", .{ lastTyped, lastTyped });

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
                        world[toIndex(player.pos)].item = null;
                    }
                } else {
                    if (doorTile) |doorTilePtr| {
                        const door = &doorTilePtr.item.?.door;
                        door.isOpen = !door.isOpen;
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
            27 => break, // esc
            else => {},
        }

        lastTyped = @intCast(input);

        const targetCoord = Coord{
            .x = player.pos.x + desiredMove.x,
            .y = player.pos.y + desiredMove.y,
        };

        const targetTile = &world[toIndex(targetCoord)];
        const doorExistsAndIsClosed = if (targetTile.item) |item| (item == .door and !item.door.isOpen) else false;

        if (targetTile.tileType == .Air and !doorExistsAndIsClosed) {
            player.pos = targetCoord;
        }
    }
}
