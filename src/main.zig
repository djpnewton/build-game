const std = @import("std");

const rl = @import("raylib");
const rg = @import("raygui");

const ut = @import("utils.zig");
const gmap = @import("map.zig");
const input = @import("input.zig");
const robot_mod = @import("robot.zig");
const footsteps_mod = @import("footsteps.zig");

pub fn main(_: std.process.Init) !void {
    // Initialization
    //--------------------------------------------------------------------------------------

    const screenWidth: i32 = @as(i32, @intCast(gmap.COLS)) * gmap.TILE_SIZE;
    const screenHeight: i32 = @as(i32, @intCast(gmap.ROWS)) * gmap.TILE_SIZE;

    rl.setConfigFlags(rl.ConfigFlags{ .window_resizable = true, .msaa_4x_hint = true });
    rl.initWindow(screenWidth, screenHeight, "build-game");
    defer rl.closeWindow(); // Close window and OpenGL context

    // virtual map
    var game_map: gmap.Map = .{};
    var footsteps: footsteps_mod.Footsteps = .{};

    // load robot
    var robot = robot_mod.Robot.load() catch {
        rl.closeWindow();
        std.debug.print("Failed to load robot textures\n", .{});
        return;
    };
    defer robot.unload();

    rl.setTargetFPS(60);
    //--------------------------------------------------------------------------------------

    // Main game loop
    while (!rl.windowShouldClose()) {
        // Update
        //----------------------------------------------------------------------------------
        const tile = robot.update();
        game_map.revealAround(tile.col, tile.row, 3);
        footsteps.update(tile, robot.dir);

        // Draw
        //----------------------------------------------------------------------------------
        rl.beginDrawing();
        defer rl.endDrawing();
        rl.clearBackground(ut.getBackgroundColor());

        game_map.draw();
        footsteps.draw();
        robot.draw();
        input.drawJoystick();
    }
}
