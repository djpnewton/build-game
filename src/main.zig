const std = @import("std");

const rl = @import("raylib");
const rg = @import("raygui");

const ut = @import("utils.zig");
const gmap = @import("map.zig");
const input = @import("input.zig");
const robot_mod = @import("robot.zig");
const footsteps_mod = @import("footsteps.zig");
const objects_mod = @import("objects.zig");
const camera_mod = @import("camera.zig");
const pathfinding = @import("pathfinding.zig");
const anim = @import("animations.zig");

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
    var camera: camera_mod.Camera = .{};

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

    // pathfinding buffer
    var path_buf: [gmap.COLS * gmap.ROWS]gmap.TilePos = undefined;

    // Set our game to run at 60 frames-per-second
    rl.setTargetFPS(60);
    //--------------------------------------------------------------------------------------

    // Main game loop
    while (!rl.windowShouldClose()) {
        // Update
        //----------------------------------------------------------------------------------
        const tile = robot.update(&game_map);
        game_map.revealAround(tile.col, tile.row, 3);
        footsteps.update(tile, robot.dir);
        camera.follow(robot.pos.x, robot.pos.y);
        const off = camera.offset();
        input.pollAll();

        // Tap (mouse click or touch tap) for pathfind to tapped tile
        if (input.consumeTap()) |tap| {
            const click_col: i32 = @intFromFloat(@floor((tap.x - off.x) / gmap.TILE_SIZE_F));
            const click_row: i32 = @intFromFloat(@floor((tap.y - off.y) / gmap.TILE_SIZE_F));
            if (click_col >= 0 and click_col < gmap.COLS and
                click_row >= 0 and click_row < gmap.ROWS)
            {
                const start = gmap.tileFromPos(robot.pos);
                const n = pathfinding.findPathTo(
                    &game_map,
                    start,
                    .{ .col = click_col, .row = click_row },
                    &path_buf,
                );
                if (n > 0) {
                    robot.setPath(path_buf[0..n]);
                    anim.startRipple(path_buf[n - 1].col, path_buf[n - 1].row);
                }
            }
        }
        anim.update();

        // Draw
        //------------------------------------------------------------------------------------
        rl.beginDrawing();
        defer rl.endDrawing();
        rl.clearBackground(ut.getBackgroundColor());

        game_map.draw(off.x, off.y);
        footsteps.draw(off.x, off.y);
        obj_map.draw(&game_map, off.x, off.y);
        anim.draw(off.x, off.y);
        robot.draw(off.x, off.y);
        input.drawJoystick();
    }
}
