const std = @import("std");

const ray = @cImport({
    @cInclude("raylib.h");
});

const game = @import("manager.zig");

pub fn main() !void {
    // initializations
    const window_width = game.window_width;
    const window_height = game.window_height;
    const tile_size_x = game.tile_size_x;
    const tile_size_y = game.tile_size_y;
    const target_fps = game.target_fps;

    ray.InitWindow(window_width, window_height, "Ray ZigTris");
    ray.SetTargetFPS(target_fps);
    defer ray.CloseWindow();

    // Audio
    ray.InitAudioDevice();
    defer ray.CloseAudioDevice();
    const sounds = ray.LoadSound("resources/clear.wav");
    defer ray.UnloadSound(sounds);

    var game_manager = game.Manager{
        .board_pos = game.board_pos,
        .tablero = game.new_tablero(),
        .camera = ray.Camera2D{
            .zoom = 1,
        },
        .tile_size_x = tile_size_x,
        .tile_size_y = tile_size_y,
        .sounds = sounds,
    };

    // game loop
    while (!ray.WindowShouldClose() and !game_manager.exit) {
        // UPDATE
        try game_manager.update_screen();

        // DRAW
        ray.BeginDrawing();
        ray.ClearBackground(ray.WHITE);
        game_manager.draw_screen();
        ray.EndDrawing();
    }
}
