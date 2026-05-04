const std = @import("std");

const rl = @import("raylib");

const gmap = @import("map.zig");
const robot_mod = @import("robot.zig");
const footsteps_mod = @import("footsteps.zig");

pub const red: gmap.TilePos = .{ .col = 3, .row = 16 };
pub const blue: gmap.TilePos = .{ .col = 16, .row = 3 };

var last_dest: gmap.TilePos = .{ .col = -1, .row = -1 };

/// Call each frame with the robot's current tile. Teleports and returns the
/// new tile if a portal was used, otherwise returns null.
pub fn tryTeleport(
    tile: gmap.TilePos,
    robot: *robot_mod.Robot,
    fs: *footsteps_mod.Footsteps,
    map: *gmap.TileMap,
) ?gmap.TilePos {
    if (check(tile)) |dest| {
        if (tile.col != last_dest.col or tile.row != last_dest.row) {
            robot.teleport(dest);
            fs.resetLastTile();
            map.revealAround(dest.col, dest.row, 3);
            last_dest = dest;
            return dest;
        }
    } else {
        last_dest = .{ .col = -1, .row = -1 };
    }
    return null;
}

fn check(tile: gmap.TilePos) ?gmap.TilePos {
    if (tile.col == red.col and tile.row == red.row) return blue;
    if (tile.col == blue.col and tile.row == blue.row) return red;
    return null;
}

pub fn draw(map: *const gmap.TileMap, off_x: f32, off_y: f32) void {
    drawPortal(map, off_x, off_y, red, rl.Color.init(220, 50, 50, 255), rl.Color.init(255, 120, 120, 180));
    drawPortal(map, off_x, off_y, blue, rl.Color.init(50, 100, 220, 255), rl.Color.init(120, 160, 255, 180));
}

fn drawPortal(
    map: *const gmap.TileMap,
    off_x: f32,
    off_y: f32,
    pos: gmap.TilePos,
    color: rl.Color,
    glow: rl.Color,
) void {
    if (!map.visible[@intCast(pos.row)][@intCast(pos.col)]) return;

    const t: f32 = @floatCast(rl.getTime());
    const cx = off_x + @as(f32, @floatFromInt(pos.col)) * gmap.TILE_SIZE_F + gmap.TILE_SIZE_F * 0.5;
    const cy = off_y + @as(f32, @floatFromInt(pos.row)) * gmap.TILE_SIZE_F + gmap.TILE_SIZE_F * 0.5;

    // Pulsing filled inner circle
    const pulse = 0.5 + 0.5 * @sin(t * 4.0);
    const inner_alpha: u8 = @intFromFloat(40.0 + pulse * 70.0);
    rl.drawCircleV(.{ .x = cx, .y = cy }, gmap.TILE_SIZE_F * 0.36, rl.Color.init(glow.r, glow.g, glow.b, inner_alpha));

    // Two ring outlines
    const r: f32 = gmap.TILE_SIZE_F * 0.44;
    rl.drawCircleLinesV(.{ .x = cx, .y = cy }, r, color);
    rl.drawCircleLinesV(.{ .x = cx, .y = cy }, r - 2.5, color);

    // Spinning highlight dot (clockwise)
    rl.drawCircleV(.{
        .x = cx + r * @cos(t * 3.0),
        .y = cy + r * @sin(t * 3.0),
    }, 3.0, rl.Color.init(255, 255, 255, 220));

    // Counter-spinning secondary dot
    rl.drawCircleV(.{
        .x = cx + (r - 2.5) * @cos(-t * 2.0 + std.math.pi),
        .y = cy + (r - 2.5) * @sin(-t * 2.0 + std.math.pi),
    }, 2.0, glow);
}
