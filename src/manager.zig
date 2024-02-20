const std = @import("std");

const ray = @cImport({
    @cInclude("raylib.h");
});

const raygui = @cImport({
    @cInclude("raygui.h");
});

// window size defaults
pub const window_width = 1920;
pub const window_height = 1080;

// board
pub const board_pos = Point{
    .x = window_width / 3,
    .y = stitle_pos.y + 40,
};

// in tiles, just keeping the original Tetris size
pub const board_size = Point{
    .x = 10,
    .y = 20,
};

pub const board_color = ray.LIGHTGRAY;

pub const tile_size_x = 45;
pub const tile_size_y = 45;

// titles positions and fonts sizes
pub const title_pos = Point{
    .x = 20,
    .y = 20,
};
pub const title_font_size = 40;

pub const stitle_pos = Point{
    .x = 120,
    .y = 80,
};
pub const stitle_font_size = 20;

// TODO: put HUD positions

// target FPS
pub const target_fps = 120;

// structs
pub const Point = struct {
    x: c_int,
    y: c_int,
};

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
    board_pos: Point,
    tablero: [board_size.y][board_size.x]u8,

    current_screen: GameScreen = .title,
    game_state: GameState = .started,
    window_width: c_int = window_width,
    window_height: c_int = window_height,
    tile_size_x: c_int = tile_size_x,
    tile_size_y: c_int = tile_size_y,
    frames_counter: u32 = 0,
    exit: bool = false,

    pub fn reset(this: *This) !void {
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
                    this.current_screen = .gameplay;
                    this.game_state = .playing;

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

                //const player_input = this.game_map.update_player();

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

    pub fn draw_screen(this: *This) void {
        switch (this.current_screen) {
            .title => {
                ray.DrawRectangle(0, 0, window_width, window_height, ray.DARKGREEN);
                ray.DrawText("TITLE SCREEN", title_pos.x, title_pos.y, title_font_size, ray.LIGHTGRAY);
                ray.DrawText("PRESS ENTER or TAP to JUMP to GAMEPLAY SCREEN", stitle_pos.x, stitle_pos.y, stitle_font_size, ray.LIGHTGRAY);
            },
            .gameplay => {
                ray.DrawRectangle(0, 0, window_width, window_height, ray.BLACK);
                ray.DrawText("GAMEPLAY SCREEN", title_pos.x, title_pos.y, title_font_size, ray.LIGHTGRAY);
                ray.DrawText("PRESS ENTER to JUMP to ENDING SCREEN", stitle_pos.x, stitle_pos.y, stitle_font_size, ray.LIGHTGRAY);

                ray.BeginMode2D(this.camera);
                this.draw_board();
                this.draw_hud();
                this.draw_pieces();
                ray.EndMode2D();

                if (this.game_state == .paused) {
                    ray.DrawText("GAME PAUSED", window_width / 3, window_height / 2, title_font_size, ray.GREEN);
                }
            },
            .ending => {
                var end_message: [:0]const u8 = "GAME OVER";
                if (this.game_state == .finished) {
                    end_message = "GAME BEATEN!!!";
                }

                ray.DrawRectangle(0, 0, window_width, window_height, ray.DARKBLUE);
                ray.DrawText(end_message, title_pos.x, title_pos.y, title_font_size, ray.LIGHTGRAY);
                ray.DrawText("PRESS ENTER to RETURN to TITLE SCREEN", stitle_pos.x, stitle_pos.y, stitle_font_size, ray.LIGHTGRAY);

                if (raygui.GuiButton(.{ .x = 100, .y = 100, .width = 200, .height = 100 }, "PRESS TO EXIT") == 1) {
                    std.log.debug("pressed\n", .{});
                    this.exit = true;
                }
            },
        }
    }
    fn draw_pieces(this: *This) void {
        _ = this; // autofix
        // const player_pos = this.player.pos;
        // const pos_x: c_int = player_pos.x * this.tile_size_x + this.map_pos.x;
        // const pos_y: c_int = player_pos.y * this.tile_size_y + this.map_pos.y;
    }

    fn draw_board(this: *This) void {
        this.draw_background();
    }

    fn draw_background(this: *This) void {
        draw_grid(this.board, board_pos, this.tile_size_x, this.tile_size_y, board_size);
    }

    fn draw_hud(this: *This) void {
        ray.DrawText("NEXT", this.board_pos.x - 300, @divTrunc(this.window_height, 6), title_font_size, ray.VIOLET);

        // NEXT piece
        const next_piece_pos = Point{
            .x = this.board_pos.x - 360,
            .y = @divTrunc(this.window_height, 6) + 50,
        };

        draw_grid(ray.Rectangle{
            .width = @floatFromInt(this.tile_size_x * 5),
            .height = @floatFromInt(this.tile_size_y * 5),
            .x = @floatFromInt(next_piece_pos.x),
            .y = @floatFromInt(next_piece_pos.y),
        }, next_piece_pos, this.tile_size_x, this.tile_size_y, Point{ .x = 5, .y = 5 });

        // POINTS
        const points_pos_x: c_int = this.tile_size_x * @as(c_int, board_size.x) + 200 + this.board_pos.x;
        ray.DrawText("SCORE", points_pos_x, @divTrunc(this.window_height, 6), title_font_size, ray.VIOLET);
        ray.DrawRectangleLinesEx(ray.Rectangle{
            .width = 200,
            .height = 50,
            .x = @floatFromInt(points_pos_x - 30),
            .y = @floatFromInt(next_piece_pos.y),
        }, 2, ray.LIGHTGRAY);
    }
};

// creates a new empty tablero
pub fn new_tablero() [board_size.y][board_size.x]u8 {
    var ta: [board_size.y][board_size.x]u8 = undefined;

    for (0..board_size.y) |y| {
        const row = [_]u8{'0'} ** board_size.x;
        ta[y] = row;
    }

    std.log.debug("TABLERO: {s}\n", .{ta});
    return ta;
}

fn draw_grid(
    rec: ray.Rectangle,
    pos: Point,
    t_size_x: c_int,
    t_size_y: c_int,
    size: Point,
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
