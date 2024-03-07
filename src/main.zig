const std = @import("std");
const c = @cImport({
    @cInclude("conio.h");
});

const Coord = struct {
    x: i32,
    y: i32,

    fn equals(a: Coord, b: Coord) bool {
        return a.x == b.x and a.y == b.y;
    }
};

const zero = Coord{ .x = 0, .y = 0 };

const Player = struct {
    pos: Coord,
};

const TileType = enum {
    Air,
    Wall,
    ExplosionSmoke,
};

const Tile = struct {
    pos: Coord = .{ .x = 0, .y = 0 },
    tileType: TileType = .Air,
    item: ?Item = null,

    fn isClear(self: Tile) bool {
        return self.item == null and self.tileType == .Air;
    }
};

// -- Items --

const KeyType = enum { Red, Blue, Green };

const Key = struct {
    keyType: KeyType,

    fn getKeyString(self: Key) []const u8 {
        return @tagName(self.keyType);
    }

    fn toString(comptime self: Key) []const u8 {
        return @tagName(self.keyType) ++ " key";
    }
};

const Door = struct {
    keyType: KeyType,
    isOpen: bool,
};

const Info = struct {
    message: []const u8,
};

const Bomb = struct {
    timer: i8 = 5,
    armed: bool = false,
};

const Bucket = struct {
    waterAmount: i32 = 0,
};

const Item = union(enum) {
    key: Key,
    door: Door,
    info: Info,
    bomb: Bomb,
    bucket: Bucket,

    fn getSymbol(self: Item) u8 {
        return switch (self) {
            .key => 'f',
            .door => if (self.door.isOpen) '\'' else 'D',
            .info => '?',
            .bomb => |bomb| if (bomb.armed) @intCast(48 + bomb.timer) else '=',
            .bucket => 'U',
        };
    }

    fn print(self: Item, stdout: anytype) !void {
        switch (self) {
            .key => |key| try stdout.print("{s} key", .{@tagName(key.keyType)}),
            .door => |door| try stdout.print("{s} door", .{@tagName(door.keyType)}),
            .info => {},
            .bomb => try stdout.print("bomb", .{}),
            .bucket => try stdout.print("bucket", .{}),
        }
    }
};

const screenWidth: i32 = 30;
const screenHeight: i32 = 10;

const worldWidth: i32 = 256;
const worldHeight: i32 = 256;

fn c2i(pos: Coord) u32 {
    return @intCast(pos.y * worldWidth + pos.x);
}

fn xy2i(x: i32, y: i32) u32 {
    return @intCast(y * worldWidth + x);
}

fn i2c(i: u32) Coord {
    return Coord{
        .x = @intCast(i % worldWidth),
        .y = @intCast(@divFloor(i, worldWidth)),
    };
}

fn placeRoom(world: []Tile, x: i32, y: i32, w: i32, h: i32) void {
    for (0..@intCast(w)) |xi| {
        for (0..@intCast(h)) |yi| {
            const xi32: i32 = @intCast(xi);
            const yi32: i32 = @intCast(yi);
            world[xy2i(x + xi32, y + yi32)].tileType = .Air;
        }
    }
}

pub fn main() !void {
    const stdout_file = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout_file);
    const stdout = bw.writer();

    var screen = [_]u8{'.'} ** (screenWidth * screenHeight);
    screen[0] = '#';

    var world = [_]Tile{.{ .tileType = .Wall }} ** (worldWidth * worldHeight);

    for (&world, 0..world.len) |*tile, i| {
        tile.pos = i2c(@intCast(i));
        //try stdout.print("index: {}, coord x: {}, y: {}\n", .{ i, tile.pos.x, tile.pos.y });
    }

    placeRoom(&world, 2, 2, 6, 6);
    placeRoom(&world, 10, 2, 12, 6);
    placeRoom(&world, 5, 5, 5, 1);
    placeRoom(&world, 23, 4, 50, 50);
    placeRoom(&world, 22, 4, 1, 1);

    world[xy2i(5, 5)].tileType = .Wall;

    world[xy2i(2, 2)].item = .{ .key = .{ .keyType = .Red } };
    world[xy2i(5, 7)].item = .{ .key = .{ .keyType = .Red } };
    world[xy2i(9, 5)].item = .{ .door = .{ .keyType = .Red, .isOpen = false } };

    world[xy2i(2, 3)].item = .{ .info = .{ .message = "Hello world!" } };
    world[xy2i(2, 4)].item = .{ .info = .{ .message = "Welcome to the dungeon!!" } };
    world[xy2i(2, 6)].item = .{ .info = .{ .message = "This is a very scary, very scary dungeon!!!" } };

    world[xy2i(5, 6)].item = .{ .bomb = .{} };
    world[xy2i(6, 6)].item = .{ .bomb = .{} };
    world[xy2i(7, 6)].item = .{ .bomb = .{} };

    world[xy2i(12, 6)].item = .{ .bucket = .{} };

    // for (0..6) |i| {
    //     world[toIndexXY(@intCast(i + 10), 6)].tileType = .Wall;
    // }

    var player = Player{ .pos = .{ .x = 3, .y = 3 } };

    var heldItem: ?Item = null;

    var lastTyped: u8 = ' ';

    // #LOOP
    while (true) {
        //@memset(&screen, '.');

        var screenStart = Coord{
            .x = player.pos.x - @divFloor(screenWidth, 2),
            .y = player.pos.y - @divFloor(screenHeight, 2),
        };

        const maxScreenX = worldWidth - screenWidth;
        const maxScreenY = worldHeight - screenHeight;

        if (screenStart.x < 0) {
            screenStart.x = 0;
        } else if (screenStart.x > maxScreenX) {
            screenStart.y = maxScreenX;
        }

        if (screenStart.y < 0) {
            screenStart.y = 0;
        } else if (screenStart.y > maxScreenY) {
            screenStart.y = maxScreenY;
        }

        // Filling screen buffer
        var sy: i32 = 0;
        while (sy < screenHeight) : (sy += 1) {
            var sx: i32 = 0;
            while (sx < screenWidth) : (sx += 1) {
                const worldCoord = Coord{
                    .x = screenStart.x + sx,
                    .y = screenStart.y + sy,
                };

                const tile = &world[c2i(worldCoord)];
                const pixel = &screen[@intCast(sy * screenWidth + sx)];

                pixel.* = switch (tile.tileType) {
                    .Air => '.',
                    .Wall => '#',
                    .ExplosionSmoke => 'x',
                };

                if (tile.item) |item| {
                    pixel.* = item.getSymbol();
                }

                if (worldCoord.equals(player.pos))
                    pixel.* = '@';
            }
        }

        // Clear screen
        try stdout.print("\x1B[2J\x1B[3J\x1B[H", .{});

        // Draw the world
        for (0..screenHeight) |y| {
            try stdout.print("\n", .{});
            for (0..screenWidth) |x| {
                try stdout.print("{c}", .{screen[y * screenWidth + x]});
            }
        }

        try stdout.print("\n", .{});

        const playerTile = &world[c2i(player.pos)];

        var itemToTake: ?Item = null;

        if (playerTile.item) |playerTileItem| {
            switch (playerTileItem) {
                .info => |info| try stdout.print("\nMessage: {s}", .{info.message}),
                else => |item| {
                    // For items that can be taken:

                    try stdout.print("\nStanding on: ", .{});

                    try item.print(stdout);
                    itemToTake = playerTileItem;

                    try stdout.print(". Press space to take", .{});
                },
            }
        }

        if (heldItem) |item| {
            try stdout.print("\nHolding: ", .{});
            try item.print(stdout);

            if (playerTile.item == null) {
                try stdout.print(". Press E to drop", .{});
            }
        }

        var doorTile: ?*Tile = null;

        if (heldItem) |item| {
            if (item == .key) {
                var y: i32 = player.pos.y - 1;
                while (y <= player.pos.y + 1) : (y += 1) {
                    var x: i32 = player.pos.x - 1;
                    while (x <= player.pos.x + 1) : (x += 1) {
                        const tile = &world[xy2i(x, y)];

                        if (tile.item) |tileItem| {
                            if (tileItem == .door) {
                                doorTile = tile;
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

        for (&world) |*tile| {
            if (tile.tileType == .ExplosionSmoke) {
                tile.tileType = .Air;
            }
        }

        // Update items state
        for (&world) |*tile| {
            if (tile.item != null and tile.item.? == .bomb and tile.item.?.bomb.armed) {
                tile.item.?.bomb.timer -= 1;

                if (tile.item.?.bomb.timer < 0) {
                    // #BOOM
                    tile.item = null;

                    const tp = tile.pos;

                    var by: i32 = tp.y - 1;
                    while (by <= tp.y + 1) : (by += 1) {
                        var bx: i32 = tp.x - 1;
                        while (bx <= tp.x + 1) : (bx += 1) {
                            world[xy2i(bx, by)].item = null;
                            world[xy2i(bx, by)].tileType = .ExplosionSmoke;
                        }
                    }
                }
            }
        }

        var desiredMove = zero;

        switch (input) {
            'a' => desiredMove.x = -1,
            'd' => desiredMove.x = 1,
            'w' => desiredMove.y = -1,
            's' => desiredMove.y = 1,
            ' ' => {
                if (itemToTake) |item| { // Taking an item
                    if (heldItem == null) {
                        heldItem = item;
                        world[c2i(player.pos)].item = null;
                    }
                } else {
                    if (heldItem) |item| {
                        if (item == .bomb and playerTile.isClear()) {
                            playerTile.item = heldItem;
                            heldItem = null;

                            playerTile.item.?.bomb.armed = true;
                        }
                    }
                    if (doorTile) |doorTilePtr| { // Unlocking the door
                        const door = &doorTilePtr.item.?.door;
                        door.isOpen = !door.isOpen;
                    }
                }
            },
            'e' => {
                if (heldItem) |item| {
                    if (playerTile.item == null) {
                        world[c2i(player.pos)].item = item;
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

        const targetTile = &world[c2i(targetCoord)];
        const doorExistsAndIsClosed = if (targetTile.item) |item| (item == .door and !item.door.isOpen) else false;

        if (targetTile.tileType == .Air and !doorExistsAndIsClosed) {
            player.pos = targetCoord;
        }
    }
}
