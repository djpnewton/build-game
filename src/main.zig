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
const inventory = @import("inventory.zig");

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
        if (world.tryCollectKey(tile)) inventory.has_key = true;

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
                    const tap_tile = gmap.TilePos{ .col = click_col, .row = click_row };
                    const kind_at = world.activeObjMap().findKindAt(click_col, click_row);
                    const choppable = kind_at == .tree or kind_at == .rock or kind_at == .rock_large;
                    const is_gate = kind_at == .gate;
                    if (is_gate) {
                        if (world.key_collected) {
                            if (isAdjacent(tile, tap_tile)) {
                                _ = world.tryOpenGate(click_col, click_row);
                            } else if (findBestAdjacentWalkable(active_map, click_col, click_row, tile, &path_buf)) |adj| {
                                const start = gmap.tileFromPos(robot.pos);
                                const n = pathfinding.findPathTo(active_map, start, adj, &path_buf);
                                if (n > 0) {
                                    robot.setPath(path_buf[0..n]);
                                    anim.startRipple(adj.col, adj.row);
                                }
                            }
                        }
                    } else if (choppable) {
                        if (isAdjacent(tile, tap_tile)) {
                            const destroyed = world.activeObjMap().chop(active_map, click_col, click_row);
                            anim.startChop(click_col, click_row);
                            if (destroyed) |k| switch (k) {
                                .tree => inventory.addWood(1, click_col, click_row),
                                .rock => inventory.addStone(1, click_col, click_row),
                                .rock_large => inventory.addStone(4, click_col, click_row),
                                else => {},
                            };
                        } else if (findBestAdjacentWalkable(active_map, click_col, click_row, tile, &path_buf)) |adj| {
                            // Navigate toward the object; player taps again to chop.
                            const start = gmap.tileFromPos(robot.pos);
                            const n = pathfinding.findPathTo(active_map, start, adj, &path_buf);
                            if (n > 0) {
                                robot.setPath(path_buf[0..n]);
                                anim.startRipple(adj.col, adj.row);
                            }
                        }
                    } else {
                        const start = gmap.tileFromPos(robot.pos);
                        const n = pathfinding.findPathTo(active_map, start, tap_tile, &path_buf);
                        if (n > 0) {
                            robot.setPath(path_buf[0..n]);
                            anim.startRipple(path_buf[n - 1].col, path_buf[n - 1].row);
                        }
                    }
                }
            }
        } else {
            if (@intFromEnum(rl.getKeyPressed()) != 0 or input.consumeTap() != null) show_congrats = false;
        }
        anim.update();
        inventory.update();

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
        inventory.draw();
        inventory.drawPopups(off.x, off.y);

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

fn isAdjacent(a: gmap.TilePos, b: gmap.TilePos) bool {
    const dc = a.col - b.col;
    const dr = a.row - b.row;
    return dc >= -1 and dc <= 1 and dr >= -1 and dr <= 1 and (dc != 0 or dr != 0);
}

fn findBestAdjacentWalkable(
    map: *const gmap.TileMap,
    col: i32,
    row: i32,
    from: gmap.TilePos,
    path_buf: []gmap.TilePos,
) ?gmap.TilePos {
    const deltas = [_][2]i32{ .{ 0, -1 }, .{ 0, 1 }, .{ -1, 0 }, .{ 1, 0 }, .{ -1, -1 }, .{ 1, -1 }, .{ -1, 1 }, .{ 1, 1 } };
    var best: ?gmap.TilePos = null;
    var best_len: usize = std.math.maxInt(usize);
    for (deltas) |d| {
        const nc = col + d[0];
        const nr = row + d[1];
        if (nc < 0 or nc >= gmap.COLS or nr < 0 or nr >= gmap.ROWS) continue;
        if (map.isBlocked(nc, nr)) continue;
        const cand = gmap.TilePos{ .col = nc, .row = nr };
        const n = pathfinding.findPathTo(map, from, cand, path_buf);
        if (n > 0 and n < best_len) {
            best_len = n;
            best = cand;
        }
    }
    return best;
}
