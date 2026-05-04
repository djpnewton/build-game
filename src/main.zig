const std = @import("std");

const rl = @import("raylib");
const rg = @import("raygui");

const ut = @import("utils.zig");
const gmap = @import("map.zig");
const input = @import("input.zig");
const robot_mod = @import("robot.zig");
const footsteps_mod = @import("footsteps.zig");
const objects_mod = @import("objects.zig");

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
    var obj_map: objects_mod.ObjectMap = .{};

    // Scatter trees across the map, avoiding the robot's starting area
    {
        var col: i32 = 1;
        while (col < gmap.COLS - 1) : (col += 1) {
            var row: i32 = 1;
            while (row < gmap.ROWS - 1) : (row += 1) {
                if (@abs(col - @as(i32, gmap.COLS / 2)) < 4 and @abs(row - @as(i32, gmap.ROWS / 2)) < 4) continue;
                // Large rocks (placed first so smaller objects won't spawn on top)
                var g: u32 = @as(u32, @bitCast(col)) *% 2246822519;
                g ^= @as(u32, @bitCast(row)) *% 2654435761;
                g = (g ^ (g >> 13)) *% 1274126177;
                g ^= g >> 16;
                if (g % 18 == 0) obj_map.place(&game_map, col, row, .rock_large);
                // Trees
                var h: u32 = @as(u32, @bitCast(col)) *% 374761393;
                h ^= @as(u32, @bitCast(row)) *% 668265263;
                h = (h ^ (h >> 13)) *% 1274126177;
                h ^= h >> 16;
                if (h % 5 == 0) obj_map.place(&game_map, col, row, .tree);
                // Small rocks
                var r: u32 = @as(u32, @bitCast(col)) *% 668265263;
                r ^= @as(u32, @bitCast(row)) *% 374761393;
                r = (r ^ (r >> 13)) *% 1274126177;
                r ^= r >> 16;
                if (r % 11 == 0) obj_map.place(&game_map, col, row, .rock);
            }
        }
    }

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
        const tile = robot.update(&game_map);
        game_map.revealAround(tile.col, tile.row, 3);
        footsteps.update(tile, robot.dir);

        // Draw
        //----------------------------------------------------------------------------------
        rl.beginDrawing();
        defer rl.endDrawing();
        rl.clearBackground(ut.getBackgroundColor());

        game_map.draw();
        footsteps.draw();
        obj_map.draw(&game_map);
        robot.draw();
        input.drawJoystick();
    }
}
