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
const portals = @import("portals.zig");

pub fn main(_: std.process.Init) !void {
    // Initialization
    //--------------------------------------------------------------------------------------

    const screenWidth: i32 = @as(i32, @intCast(gmap.COLS)) * gmap.TILE_SIZE;
    const screenHeight: i32 = @as(i32, @intCast(gmap.ROWS)) * gmap.TILE_SIZE;

    rl.setConfigFlags(rl.ConfigFlags{ .window_resizable = true, .msaa_4x_hint = true });
    rl.initWindow(screenWidth, screenHeight, "build-game");
    defer rl.closeWindow(); // Close window and OpenGL context

    // virtual map
    var camera: camera_mod.Camera = .{};
    var game_map: gmap.Map = .{};
    var footsteps: footsteps_mod.Footsteps = .{};
    var obj_map: objects_mod.ObjectMap = .{};
    obj_map.scatter(&game_map);

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
        _ = portals.tryTeleport(tile, &robot, &footsteps, &game_map);
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
        portals.draw(&game_map, off.x, off.y);
        footsteps.draw(off.x, off.y);
        obj_map.draw(&game_map, off.x, off.y);
        anim.draw(off.x, off.y);
        robot.draw(off.x, off.y);
        input.drawJoystick();
    }
}
