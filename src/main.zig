const std = @import("std");

const rl = @import("raylib");
const rg = @import("raygui");

const ut = @import("utils.zig");
const gmap = @import("map.zig");
const world_mod = @import("world.zig");
const input = @import("input.zig");
const robot_mod = @import("robot.zig");
const footsteps_mod = @import("footsteps.zig");
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

    var camera: camera_mod.Camera = .{};
    var world: world_mod.WorldState = .{};
    world.init();
    var footsteps: footsteps_mod.Footsteps = .{};

    // load robot
    var robot = robot_mod.Robot.load() catch {
        rl.closeWindow();
        std.debug.print("Failed to load robot textures\n", .{});
        return;
    };
    defer robot.unload();

    // pathfinding buffer
    var path_buf: [gmap.COLS * gmap.ROWS]gmap.TilePos = undefined;
    var show_congrats: bool = false;

    // Set our game to run at 60 frames-per-second
    rl.setTargetFPS(60);
    //--------------------------------------------------------------------------------------

    // Main game loop
    while (!rl.windowShouldClose()) {
        // Update
        //----------------------------------------------------------------------------------
        const active_map = world.activeMap();
        const tile = robot.update(active_map);

        world.trySceneTransition(tile, &robot, &footsteps);
        if (world.tryCollectDiamond(tile)) show_congrats = true;

        active_map.revealAround(tile.col, tile.row, 3);
        footsteps.update(tile, robot.dir);
        camera.follow(robot.pos.x, robot.pos.y);
        const off = camera.offset();
        input.pollAll();

        // Tap (mouse click or touch tap) for pathfind to tapped tile
        if (!show_congrats) {
            if (input.consumeTap()) |tap| {
                const click_col: i32 = @intFromFloat(@floor((tap.x - off.x) / gmap.TILE_SIZE_F));
                const click_row: i32 = @intFromFloat(@floor((tap.y - off.y) / gmap.TILE_SIZE_F));
                if (click_col >= 0 and click_col < gmap.COLS and
                    click_row >= 0 and click_row < gmap.ROWS)
                {
                    const start = gmap.tileFromPos(robot.pos);
                    const n = pathfinding.findPathTo(
                        active_map,
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
        } else {
            if (@intFromEnum(rl.getKeyPressed()) != 0 or input.consumeTap() != null) show_congrats = false;
        }
        anim.update();

        // Draw
        //------------------------------------------------------------------------------------
        world.prepareFrameCache(); // update tile caches before opening the framebuffer
        footsteps.updateCache();
        rl.beginDrawing();
        defer rl.endDrawing();
        rl.clearBackground(ut.getBackgroundColor());

        world.draw(off.x, off.y);
        footsteps.draw(off.x, off.y);
        anim.draw(off.x, off.y);
        robot.draw(off.x, off.y);
        input.drawJoystick();

        // FPS counter – top-right corner
        const fps = rl.getFPS();
        var fps_buf: [16]u8 = undefined;
        const fps_str = std.fmt.bufPrintZ(&fps_buf, "{d} FPS", .{fps}) catch "? FPS";
        const fs: i32 = 14;
        const fw = rl.measureText(fps_str, fs);
        rl.drawText(fps_str, rl.getRenderWidth() - fw - 5, 7, fs, rl.Color.init(0, 0, 0, 180));
        rl.drawText(fps_str, rl.getRenderWidth() - fw - 6, 6, fs, rl.Color.init(255, 255, 255, 180));

        if (show_congrats) {
            const sw: i32 = rl.getRenderWidth();
            const sh: i32 = rl.getRenderHeight();
            rl.drawRectangle(0, 0, sw, sh, rl.Color.init(0, 0, 0, 160));
            const pw: i32 = 340;
            const ph: i32 = 190;
            const px = @divFloor(sw - pw, 2);
            const py = @divFloor(sh - ph, 2);
            rl.drawRectangle(px, py, pw, ph, rl.Color.init(15, 18, 35, 245));
            rl.drawRectangleLines(px, py, pw, ph, rl.Color.init(150, 220, 255, 200));
            rl.drawRectangleLines(px + 2, py + 2, pw - 4, ph - 4, rl.Color.init(100, 160, 220, 80));
            const title = "Congratulations!";
            const title_fs: i32 = 28;
            const title_w = rl.measureText(title, title_fs);
            rl.drawText(title, px + @divFloor(pw - title_w, 2), py + 28, title_fs, rl.Color.init(255, 220, 50, 255));
            const sub = "You found the diamond!";
            const sub_fs: i32 = 18;
            const sub_w = rl.measureText(sub, sub_fs);
            rl.drawText(sub, px + @divFloor(pw - sub_w, 2), py + 76, sub_fs, rl.Color.init(200, 240, 255, 255));
            const t_now: f32 = @floatCast(rl.getTime());
            const blink_a: u8 = @intFromFloat(128.0 + 127.0 * @sin(t_now * 3.0));
            const hint = "Press any key to continue";
            const hint_fs: i32 = 14;
            const hint_w = rl.measureText(hint, hint_fs);
            rl.drawText(hint, px + @divFloor(pw - hint_w, 2), py + 148, hint_fs, rl.Color.init(180, 180, 180, blink_a));
        }
    }
}
