const std = @import("std");
const t = std.testing;

const ray = @cImport({
    @cInclude("raylib.h");
});

const raygui = @cImport({
    @cInclude("raygui.h");
});

const piece = @import("piece.zig");
const model = @import("model.zig");

// window size defaults
pub const window_width = 1920;
pub const window_height = 1080;

// board
pub const board_pos = model.Point{
    .x = window_width / 3,
    .y = stitle_pos.y + 40,
};

// in tiles, just keeping the original Tetris size
pub const board_size = model.Point{
    .x = 10,
    .y = 20,
};

pub const board_color = ray.LIGHTGRAY;

pub const tile_size_x = 45;
pub const tile_size_y = 45;

// titles positions and fonts sizes
pub const title_pos = model.Point{
    .x = window_width / 3 + 150,
    .y = window_height / 4,
};
pub const title_font_size = 50;

pub const stitle_pos = model.Point{
    .x = 120,
    .y = 50,
};
pub const stitle_font_size = 30;

// TODO: put HUD positions

// target FPS
pub const target_fps = 120;

// in ms
const start_gravity_period = 1000;

// game screens
pub const GameScreen = enum {
    title,
    gameplay,
    ending,
};

pub const GameState = enum {
    started,
    playing,
    paused,
    over,
    finished,
};

// Manager is a basic game manager
pub const Manager = struct {
    const This = @This();
    camera: ray.Camera2D,

    board: ray.Rectangle = ray.Rectangle{},
    board_pos: model.Point,
    tablero: Tablero,
    curr_piece: piece.Piece = undefined,
    last_gravity_push: i64 = 0,
    next_piece: piece.Piece = undefined,
    gravity_period: i64 = start_gravity_period,

    current_screen: GameScreen = .title,
    game_state: GameState = .started,
    window_width: c_int = window_width,
    window_height: c_int = window_height,
    tile_size_x: c_int = tile_size_x,
    tile_size_y: c_int = tile_size_y,
    frames_counter: u32 = 0,
    exit: bool = false,
    score: i64 = 0,
    sounds: ray.Sound,

    pub fn reset(this: *This) !void {
        this.current_screen = .gameplay;
        this.game_state = .playing;

        this.gravity_period = start_gravity_period;
        this.tablero = new_tablero();
        this.tablero.log_debug();
        this.next_piece = piece.new_shuffled();
        this.curr_piece = piece.new_shuffled();
        this.curr_piece.period = this.gravity_period;
        this.curr_piece.position = .{
            .x = 3,
            .y = 0,
        };

        this.board = ray.Rectangle{
            .width = @floatFromInt(this.tile_size_x * board_size.x),
            .height = @floatFromInt(this.tile_size_y * board_size.y),
            .x = @floatFromInt(this.board_pos.x),
            .y = @floatFromInt(this.board_pos.y),
        };
    }

    pub fn update_screen(this: *This) !void {
        switch (this.current_screen) {
            .title => {
                // Press enter to change to GAMEPLAY screen
                if (ray.IsKeyPressed(ray.KEY_ENTER) or ray.IsGestureDetected(ray.GESTURE_TAP)) {
                    try this.reset();
                }
            },
            .gameplay => {
                // Press enter to change to ENDING screen
                if (ray.IsKeyPressed(ray.KEY_ENTER)) {
                    this.current_screen = .ending;
                    this.game_state = .over;
                    return;
                }

                if (ray.IsKeyPressed(ray.KEY_P)) {
                    if (this.game_state == .paused) {
                        this.game_state = .playing;
                        return;
                    }

                    if (this.game_state == .playing) {
                        this.game_state = .paused;
                        return;
                    }
                }

                if (this.game_state == .paused) {
                    return;
                }

                this.process_key();
                this.gravity();
                const lines = this.tablero.remove_lines();
                this.update_score_and_speed(lines);

                // TODO: Game finished condition

            },
            .ending => {
                // Press enter to return to TITLE screen
                if (ray.IsKeyPressed(ray.KEY_ENTER)) {
                    std.log.debug("BACK TO TITLE", .{});
                    this.current_screen = .title;
                    this.game_state = .started;
                }
            },
        }
    }

    fn update_score_and_speed(this: *This, lines: u8) void {
        if (lines == 0) {
            return;
        }

        ray.PlaySound(this.sounds);

        std.log.debug("LINES REMOVED: {}\n", .{lines});
        this.tablero.log_debug();

        this.score += 100 * @as(i64, lines);

        // decrease gravity period / increase speed
        this.gravity_period = @max(100, start_gravity_period - (@divTrunc(this.score, 500) * 100));
    }

    fn process_key(this: *Manager) void {
        var next_pos = model.Point{
            .x = this.curr_piece.position.x,
            .y = this.curr_piece.position.y,
        };

        // rotate
        if (ray.IsKeyPressed(ray.KEY_UP)) {
            const rotated = this.curr_piece.rotate_right();
            piece.log_debug(rotated);

            if (!this.tablero.can_occupy(rotated, next_pos)) {
                return;
            }

            this.curr_piece = rotated;
        }

        // move
        if (ray.IsKeyPressed(ray.KEY_LEFT) or ray.IsKeyPressedRepeat(ray.KEY_LEFT)) {
            next_pos.x = this.curr_piece.position.x - 1;
        } else if (ray.IsKeyPressed(ray.KEY_RIGHT) or ray.IsKeyPressedRepeat(ray.KEY_RIGHT)) {
            next_pos.x = this.curr_piece.position.x + 1;
        }

        if (ray.IsKeyPressed(ray.KEY_DOWN) or ray.IsKeyPressedRepeat(ray.KEY_DOWN)) {
            next_pos.y = this.curr_piece.position.y + 1;
        }

        if (!this.tablero.can_occupy(this.curr_piece, next_pos)) {
            return;
        }

        this.curr_piece.position = next_pos;
    }

    fn gravity(this: *Manager) void {
        if (this.curr_piece.period == 0) {
            return;
        }

        if (std.time.milliTimestamp() - this.last_gravity_push < this.curr_piece.period) {
            return;
        }

        //std.log.debug("Gravity: elapsed:{d}, period:{d}", .{ (std.time.milliTimestamp() - this.last_gravity_push), this.curr_piece.period });
        defer this.last_gravity_push = std.time.milliTimestamp();

        const next_pos = model.Point{
            .x = this.curr_piece.position.x,
            .y = this.curr_piece.position.y + 1,
        };

        if (this.tablero.can_occupy(this.curr_piece, next_pos)) {
            this.curr_piece.position = next_pos;
            //std.log.debug("Can move: x:{d}, y:{d}", .{ next_pos.x, next_pos.y });
            return;
        }

        std.log.debug("Can't move: x:{d}, y:{d}", .{ next_pos.x, next_pos.y });
        _ = this.tablero.put_piece(this.curr_piece, this.curr_piece.position);
        this.tablero.log_debug();

        // GAME OVER
        if (this.curr_piece.position.y == 0) {
            this.current_screen = .ending;
            this.game_state = .over;
            return;
        }

        this.curr_piece = this.next_piece;
        this.next_piece = piece.new_shuffled();
        this.curr_piece.period = this.gravity_period;
        this.curr_piece.position = .{
            .x = 3,
            .y = 0,
        };
    }

    pub fn draw_screen(this: *This) void {
        switch (this.current_screen) {
            .title => {
                this.draw_title();
            },
            .gameplay => {
                ray.DrawRectangle(0, 0, window_width, window_height, ray.BLACK);
                ray.DrawText("PRESS ENTER to JUMP to ENDING SCREEN", stitle_pos.x, stitle_pos.y, stitle_font_size, ray.LIGHTGRAY);

                ray.BeginMode2D(this.camera);
                this.draw_board();
                this.draw_hud();
                this.draw_curr_piece();
                ray.EndMode2D();

                if (this.game_state == .paused) {
                    ray.DrawText("GAME PAUSED", window_width / 3 + 75, window_height / 2, title_font_size, ray.GREEN);
                }
            },
            .ending => {
                var end_message: [:0]const u8 = "GAME OVER";
                if (this.game_state == .finished) {
                    end_message = "GAME BEATEN!!!";
                }

                ray.DrawRectangle(0, 0, window_width, window_height, ray.BLACK);
                ray.DrawText(end_message, title_pos.x, title_pos.y, title_font_size, ray.VIOLET);
                ray.DrawText(ray.TextFormat("SCORE: %d", this.score), title_pos.x + 35, title_pos.y + 70, title_font_size, ray.LIGHTGRAY);
                ray.DrawText("PRESS ENTER to RETURN to TITLE SCREEN", stitle_pos.x, stitle_pos.y, stitle_font_size, ray.LIGHTGRAY);

                if (raygui.GuiButton(.{ .x = 100, .y = 100, .width = 200, .height = 100 }, "PRESS TO EXIT") == 1) {
                    std.log.debug("pressed\n", .{});
                    this.exit = true;
                }
            },
        }
    }

    fn draw_title(this: *This) void {
        ray.DrawRectangle(0, 0, window_width, window_height, ray.BLACK);
        ray.DrawText("RAY ZIGTRIS", title_pos.x, title_pos.y, title_font_size, ray.VIOLET);
        ray.DrawText("PRESS ENTER or MOUSE L BUTTON  to PLAY", stitle_pos.x, stitle_pos.y, stitle_font_size, ray.LIGHTGRAY);

        const grid_pos = model.Point{
            .x = title_pos.x + 30,
            .y = title_pos.y + 100,
        };
        draw_grid(ray.Rectangle{
            .width = @floatFromInt(this.tile_size_x * 6),
            .height = @floatFromInt(this.tile_size_y * 6),
            .x = grid_pos.x,
            .y = grid_pos.y,
        }, model.Point{
            .x = grid_pos.x,
            .y = grid_pos.y,
        }, this.tile_size_x, this.tile_size_y, model.Point{ .x = 6, .y = 6 });

        this.draw_piece(piece.RedBar, grid_pos);
        this.draw_piece(piece.BlueSquare, model.Point{
            .x = grid_pos.x + this.tile_size_x * 2,
            .y = grid_pos.y + this.tile_size_y * 3,
        });
        this.draw_piece(piece.LBlueS, model.Point{
            .x = grid_pos.x + this.tile_size_x * 0,
            .y = grid_pos.y + this.tile_size_y * 2,
        });
        this.draw_piece(piece.GreenT, model.Point{
            .x = grid_pos.x + this.tile_size_x * 3,
            .y = grid_pos.y + this.tile_size_y * -1,
        });
        this.draw_piece(piece.YellowL, model.Point{
            .x = grid_pos.x + this.tile_size_x * 3,
            .y = grid_pos.y + this.tile_size_y * 2,
        });
    }

    fn draw_curr_piece(this: This) void {
        this.draw_piece(this.curr_piece, model.Point{
            .x = this.board_pos.x + (this.curr_piece.position.x * tile_size_x),
            .y = this.board_pos.y + (this.curr_piece.position.y * tile_size_x),
        });
    }

    fn draw_board(this: *This) void {
        this.draw_background();
        this.draw_tablero();
    }

    fn draw_background(this: *This) void {
        draw_grid(this.board, this.board_pos, this.tile_size_x, this.tile_size_y, board_size);
    }

    fn draw_tablero(this: This) void {
        for (this.tablero.tiles, 0..) |row, y| {
            const yi: c_int = @intCast(y);
            for (row, 0..) |tile, x| {
                if (tile == piece.tile_empty) {
                    continue;
                }
                const xi: c_int = @intCast(x);

                const pos_x = this.tile_size_x * xi + this.board_pos.x;
                const pos_y = this.tile_size_y * yi + this.board_pos.y;

                ray.DrawRectangle(pos_x, pos_y, this.tile_size_x, this.tile_size_y, try piece.block_color(tile));
            }
        }
    }

    fn draw_hud(this: *This) void {
        ray.DrawText("NEXT", this.board_pos.x - 300, @divTrunc(this.window_height, 6), title_font_size, ray.VIOLET);

        // NEXT piece
        const next_piece_pos = model.Point{
            .x = this.board_pos.x - 330,
            .y = @divTrunc(this.window_height, 6) + 50,
        };

        draw_grid(ray.Rectangle{
            .width = @floatFromInt(this.tile_size_x * 4),
            .height = @floatFromInt(this.tile_size_y * 4),
            .x = @floatFromInt(next_piece_pos.x),
            .y = @floatFromInt(next_piece_pos.y),
        }, next_piece_pos, this.tile_size_x, this.tile_size_y, model.Point{ .x = 4, .y = 4 });
        this.draw_piece(this.next_piece, next_piece_pos);

        // SCORE
        const score_pos_x: c_int = this.tile_size_x * @as(c_int, board_size.x) + 200 + this.board_pos.x;
        ray.DrawText("SCORE", score_pos_x, @divTrunc(this.window_height, 6), title_font_size, ray.VIOLET);
        ray.DrawRectangleLinesEx(ray.Rectangle{
            .width = 250,
            .height = 55,
            .x = @floatFromInt(score_pos_x - 40),
            .y = @floatFromInt(next_piece_pos.y),
        }, 2, ray.LIGHTGRAY);
        ray.DrawText(ray.TextFormat("%07d", this.score), score_pos_x - 6, next_piece_pos.y + 6, title_font_size, ray.GRAY);

        // SPEED
        ray.DrawText("SPEED", score_pos_x, @divTrunc(this.window_height, 3), title_font_size, ray.VIOLET);
        const period_ms: f64 = @floatFromInt(this.gravity_period);
        ray.DrawText(ray.TextFormat("%.1f", 1000 / period_ms), score_pos_x + 60, @divTrunc(this.window_height, 3) + 50, title_font_size, ray.GRAY);
    }

    fn draw_piece(this: This, piec: piece.Piece, pos: model.Point) void {
        for (piec.tiles, 0..) |row, y| {
            for (row, 0..) |tile, x| {
                if (tile == piece.tile_empty) {
                    continue;
                }

                const xi: c_int = @intCast(x);
                const yi: c_int = @intCast(y);
                const pos_x = this.tile_size_x * xi + pos.x;
                const pos_y = this.tile_size_y * yi + pos.y;

                ray.DrawRectangle(pos_x, pos_y, this.tile_size_x, this.tile_size_y, try piece.block_color(tile));
            }
        }
    }
};

fn draw_grid(
    rec: ray.Rectangle,
    pos: model.Point,
    t_size_x: c_int,
    t_size_y: c_int,
    size: model.Point,
) void {
    // exterior
    ray.DrawRectangleLinesEx(rec, 2, board_color);

    // grid lines
    const x_lim: c_int = pos.x + t_size_x * size.x;
    const y_lim: c_int = pos.y + t_size_y * size.y;

    var col: c_int = 0;
    var row: c_int = 0;

    // vertical lines
    while (col < size.x) : (col += 1) {
        const x_of: c_int = col * t_size_x;
        ray.DrawLine(
            pos.x + x_of,
            pos.y,
            pos.x + x_of,
            y_lim,
            ray.GRAY,
        );
    }

    // horizontal lines
    while (row < size.y) : (row += 1) {
        const y_of: c_int = row * t_size_y;
        ray.DrawLine(
            pos.x,
            pos.y + y_of,
            x_lim,
            pos.y + y_of,
            ray.GRAY,
        );
    }
}

pub const Tablero = struct {
    tiles: [board_size.y][board_size.x]u8 = undefined,

    fn can_occupy(this: Tablero, p: piece.Piece, pos: model.Point) bool {
        for (p.tiles, 0..) |row, y| {
            const pos_yu: usize = @intCast(pos.y);
            const yi: c_int = @intCast(y);
            for (row, 0..) |tile, x| {
                const xi: c_int = @intCast(x);

                if (tile == piece.tile_empty) {
                    continue;
                }

                // out of bounds
                if ((pos.x + xi < 0) or (pos.y + yi < 0)) {
                    return false;
                }

                if ((pos.x + xi >= board_size.x) or (pos.y + yi >= board_size.y)) {
                    return false;
                }

                const xu: usize = @intCast(pos.x + xi);
                // already filled
                if ((this.tiles[pos_yu + y][xu] != piece.tile_empty)) {
                    return false;
                }
            }
        }
        return true;
    }

    fn put_piece(this: *Tablero, p: piece.Piece, pos: model.Point) bool {
        if (!this.can_occupy(p, pos)) {
            return false;
        }

        const pos_yu: usize = @intCast(pos.y);
        for (p.tiles, 0..) |row, y| {
            for (row, 0..) |el, x| {
                if (el == piece.tile_empty) {
                    continue;
                }

                const xi: c_int = @intCast(x);
                const xu: usize = @intCast(xi + pos.x);
                this.tiles[pos_yu + y][xu] = el;
            }
        }

        return true;
    }

    fn remove_lines(this: *Tablero) u8 {
        var lines: u8 = 0;

        while (true) {
            var removed: bool = false;
            var row: u8 = this.tiles.len;
            while (row > 0) {
                row -= 1;

                if (this.is_line(row)) {
                    this.remove_line(row);
                    lines += 1;
                    removed = true;
                }
            }

            if (!removed) {
                return lines;
            }

            this.compact();
        }
        return lines;
    }

    fn remove_line(this: *Tablero, row: u8) void {
        this.tiles[row] = [_]u8{'.'} ** board_size.x;
    }

    fn is_line(this: *Tablero, row: u8) bool {
        for (this.tiles[row]) |el| {
            if (el == piece.tile_empty) {
                return false;
            }
        }

        return true;
    }

    fn compact(this: *Tablero) void {
        var row: u8 = this.tiles.len;
        var tops = this.column_tops();

        while (row > 0) {
            row -= 1;

            for (&this.tiles[row], 0..) |*el, x| {
                if (el.* == piece.tile_empty) {
                    continue;
                }

                this.tiles[tops[x]][x] = el.*;
                el.* = piece.tile_empty;
                tops = this.column_tops();
            }
        }
    }

    // return y indexes of the tops of the columns
    fn column_tops(this: *Tablero) [board_size.x]u8 {
        var tops: [board_size.x]u8 = [_]u8{board_size.y} ** board_size.x;

        var row: u8 = this.tiles.len;
        while (row > 0) {
            row -= 1;

            for (this.tiles[row], 0..) |el, x| {
                if (el == piece.tile_empty and tops[x] == board_size.y) {
                    tops[x] = row;
                }
            }
        }

        return tops;
    }

    fn log_debug(this: Tablero) void {
        std.debug.print("Tablero:\n", .{});
        for (this.tiles, 0..) |row, i| {
            std.debug.print("row {d:0>2}-{s}\n", .{ i, row });
        }
    }
    fn copy(this: Tablero) Tablero {
        var tiles: [board_size.y][board_size.x]u8 = undefined;
        for (this.tiles, 0..) |row, y| {
            for (row, 0..) |_, x| {
                tiles[y][x] = this.tiles[y][x];
            }
        }

        return Tablero{
            .tiles = tiles,
        };
    }
};

// creates a new empty tablero
pub fn new_tablero() Tablero {
    var ta: [board_size.y][board_size.x]u8 = undefined;

    for (0..board_size.y) |y| {
        const row = [_]u8{piece.tile_empty} ** board_size.x;
        ta[y] = row;
    }

    return Tablero{
        .tiles = ta,
    };
}

test "tablero" {
    const p = piece.VioletL;
    var tab = new_tablero();

    var can = tab.can_occupy(p, model.Point{
        .x = 0,
        .y = 0,
    });
    try t.expect(can);

    can = tab.can_occupy(p, model.Point{
        .x = 0,
        .y = 17,
    });
    try t.expect(can);

    can = tab.can_occupy(p, model.Point{
        .x = 0,
        .y = 18,
    });
    try t.expect(!can);

    can = tab.can_occupy(p, model.Point{
        .x = 6,
        .y = 17,
    });
    try t.expect(can);

    can = tab.can_occupy(p, model.Point{
        .x = 8,
        .y = 17,
    });
    try t.expect(!can);

    // test occupied tile
    tab.tiles[17][6] = piece.tile_lblue;
    can = tab.can_occupy(p, model.Point{
        .x = 6,
        .y = 17,
    });
    try t.expect(can);

    tab.tiles[18][6] = piece.tile_lblue;
    can = tab.can_occupy(p, model.Point{
        .x = 6,
        .y = 17,
    });
    try t.expect(!can);

    // test put_piece
    const tab_c = tab.copy();

    var ok = tab.put_piece(piece.OrangeS, model.Point{
        .x = 5,
        .y = 15,
    });

    tab.log_debug();
    try t.expect(!ok);
    try t.expectEqualDeep(tab, tab_c);

    ok = tab.put_piece(piece.OrangeS, model.Point{
        .x = 6,
        .y = 15,
    });

    try t.expect(ok);
    tab.log_debug();

    // test remove lines
    var tab2 = new_tablero();
    tab2.tiles[13] = [10]u8{ '7', '7', '7', '7', '7', '.', '.', '.', '.', '.' };
    tab2.tiles[15] = [10]u8{ '.', '.', '.', '.', '.', '5', '5', '.', '.', '5' };
    tab2.tiles[16] = [10]u8{ '4', '4', '4', '4', '4', '4', '4', '4', '4', '4' };
    tab2.tiles[17] = [10]u8{ '.', '.', '.', '.', '.', '3', '.', '3', '3', '.' };
    tab2.tiles[18] = [10]u8{ '2', '2', '2', '2', '2', '2', '2', '2', '2', '2' };
    tab2.tiles[19] = [10]u8{ '.', '.', '.', '.', '.', '.', '1', '.', '1', '.' };
    tab2.log_debug();
    const lines = tab2.remove_lines();
    tab2.log_debug();
    try t.expectEqual(3, lines);
    try t.expectEqual([10]u8{ '.', '.', '.', '.', '.', '.', '.', '.', '.', '.' }, tab2.tiles[13]);
    try t.expectEqual([10]u8{ '.', '.', '.', '.', '.', '.', '.', '.', '.', '.' }, tab2.tiles[14]);
    try t.expectEqual([10]u8{ '.', '.', '.', '.', '.', '.', '.', '.', '.', '.' }, tab2.tiles[15]);
    try t.expectEqual([10]u8{ '.', '.', '.', '.', '.', '.', '.', '.', '.', '.' }, tab2.tiles[16]);
    try t.expectEqual([10]u8{ '.', '.', '.', '.', '.', '.', '.', '.', '.', '.' }, tab2.tiles[17]);
    try t.expectEqual([10]u8{ '.', '.', '.', '.', '.', '.', '.', '.', '.', '.' }, tab2.tiles[18]);
    try t.expectEqual([10]u8{ '.', '.', '.', '.', '.', '5', '5', '.', '3', '.' }, tab2.tiles[19]);
}
