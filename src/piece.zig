const std = @import("std");
const t = std.testing;

const ray = @cImport({
    @cInclude("raylib.h");
});

const model = @import("model.zig");

// Tiles
pub const tile_empty = '.';
pub const tile_red = '1';
pub const tile_yellow = '2';
pub const tile_violet = '3';
pub const tile_green = '4';
pub const tile_blue = '5';
pub const tile_orange = '6';
pub const tile_lblue = '7';

pub const Piece = struct {
    tiles: [4][4]u8 = undefined,
    // gravity period in ms, default no movement
    period: i64 = -1,
    position: model.Point = .{
        .x = 0,
        .y = 0,
    },

    pub fn rotate_right(this: Piece) Piece {
        var rotated: [4][4]u8 = undefined;
        for (this.tiles, 0..) |row, i| {
            for (row, 0..) |_, j| {
                rotated[i][j] = this.tiles[3 - j][i];
            }
        }

        return Piece{
            .tiles = rotated,
            .period = this.period,
            .position = this.position,
        };
    }

    pub fn move(this: *Piece, pos: model.Point) void {
        this.position = pos;
    }
};

pub fn new_shuffled() Piece {
    const seed = std.time.milliTimestamp();
    var rand_impl = std.rand.DefaultPrng.init(@intCast(seed));
    const piece_num = rand_impl.random().intRangeAtMost(u8, 0, amount - 1);

    std.debug.print("piece: {}\n", .{piece_num});

    return Pieces[piece_num];
}

const Error = error{
    Nocolor,
};

pub fn block_color(tile: u8) !ray.Color {
    return switch (tile) {
        tile_red => ray.RED,
        tile_yellow => ray.YELLOW,
        tile_violet => ray.VIOLET,
        tile_green => ray.GREEN,
        tile_blue => ray.BLUE,
        tile_orange => ray.ORANGE,
        tile_lblue => ray.Color{
            .r = 90,
            .g = 238,
            .b = 255,
            .a = 255,
        },
        else => unreachable,
    };
}

const amount = 7;
// Tetris set of pieces, used to shuffle
pub const Pieces = [amount]Piece{ RedBar, YellowL, VioletL, GreenT, BlueSquare, OrangeS, LBlueS };

pub const RedBar = Piece{
    .tiles = [4][4]u8{
        [4]u8{ '.', '.', '.', '.' },
        [4]u8{ '1', '1', '1', '1' },
        [4]u8{ '.', '.', '.', '.' },
        [4]u8{ '.', '.', '.', '.' },
    },
};

pub const YellowL = Piece{
    .tiles = [4][4]u8{
        [4]u8{ '.', '.', '.', '.' },
        [4]u8{ '2', '2', '2', '.' },
        [4]u8{ '.', '.', '2', '.' },
        [4]u8{ '.', '.', '.', '.' },
    },
};

pub const VioletL = Piece{
    .tiles = [4][4]u8{
        [4]u8{ '.', '.', '.', '.' },
        [4]u8{ '3', '3', '3', '.' },
        [4]u8{ '3', '.', '.', '.' },
        [4]u8{ '.', '.', '.', '.' },
    },
};

pub const GreenT = Piece{
    .tiles = [4][4]u8{
        [4]u8{ '.', '.', '.', '.' },
        [4]u8{ '4', '4', '4', '.' },
        [4]u8{ '.', '4', '.', '.' },
        [4]u8{ '.', '.', '.', '.' },
    },
};

pub const BlueSquare = Piece{
    .tiles = [4][4]u8{
        [4]u8{ '.', '.', '.', '.' },
        [4]u8{ '.', '5', '5', '.' },
        [4]u8{ '.', '5', '5', '.' },
        [4]u8{ '.', '.', '.', '.' },
    },
};

pub const OrangeS = Piece{
    .tiles = [4][4]u8{
        [4]u8{ '.', '.', '.', '.' },
        [4]u8{ '6', '6', '.', '.' },
        [4]u8{ '.', '6', '6', '.' },
        [4]u8{ '.', '.', '.', '.' },
    },
};

pub const LBlueS = Piece{
    .tiles = [4][4]u8{
        [4]u8{ '.', '.', '.', '.' },
        [4]u8{ '.', '7', '7', '.' },
        [4]u8{ '7', '7', '.', '.' },
        [4]u8{ '.', '.', '.', '.' },
    },
};

fn equal(p1: Piece, p2: Piece) bool {
    for (p1.tiles, p2.tiles) |row1, row2| {
        for (row1, row2) |el1, el2| {
            if (el1 != el2) {
                return false;
            }
        }
    }
    return true;
}

pub fn log_debug(piece: Piece) void {
    std.debug.print("\nPiece:\n", .{});
    for (piece.tiles, 0..) |row, i| {
        std.debug.print("row {}-{s}\n", .{ i, row });
    }
}

test "rotate_right" {
    var pi = RedBar;

    var rotated = pi.rotate_right();
    log_debug(pi);

    const vert_red_bar = Piece{
        .tiles = [4][4]u8{
            [4]u8{ '.', '.', '1', '.' },
            [4]u8{ '.', '.', '1', '.' },
            [4]u8{ '.', '.', '1', '.' },
            [4]u8{ '.', '.', '1', '.' },
        },
    };

    try t.expectEqual(vert_red_bar, rotated);

    pi = GreenT;
    rotated = pi.rotate_right();
    log_debug(pi);

    const vert_green_t = Piece{
        .tiles = [4][4]u8{
            [4]u8{ '.', '.', '4', '.' },
            [4]u8{ '.', '4', '4', '.' },
            [4]u8{ '.', '.', '4', '.' },
            [4]u8{ '.', '.', '.', '.' },
        },
    };
    try t.expectEqual(vert_green_t, rotated);
}
