const std = @import("std");
const rl = @import("raylib");

pub const TILE_SIZE: i32 = 32;
pub const TILE_SIZE_F: f32 = @floatFromInt(TILE_SIZE);
pub const COLS: usize = 20;
pub const ROWS: usize = 20;

const GRASS_LIGHT = rl.Color.init(85, 170, 85, 255);
const GRASS_DARK = rl.Color.init(70, 145, 70, 255);
const FOG_COLOR = rl.Color.init(0, 0, 0, 255);

pub const Map = struct {
    visible: [ROWS][COLS]bool = std.mem.zeroes([ROWS][COLS]bool),

    /// Reveal all tiles within `radius` tiles of (tile_col, tile_row).
    pub fn revealAround(self: *Map, tile_col: i32, tile_row: i32, radius: i32) void {
        var dy: i32 = -radius;
        while (dy <= radius) : (dy += 1) {
            var dx: i32 = -radius;
            while (dx <= radius) : (dx += 1) {
                if (dx * dx + dy * dy > radius * radius) continue;
                const c = tile_col + dx;
                const r = tile_row + dy;
                if (c < 0 or c >= COLS or r < 0 or r >= ROWS) continue;
                self.visible[@intCast(r)][@intCast(c)] = true;
            }
        }
    }

    pub fn draw(self: Map) void {
        const screen_w: f32 = @floatFromInt(rl.getRenderWidth());
        const screen_h: f32 = @floatFromInt(rl.getRenderHeight());
        const map_w: f32 = @as(f32, @floatFromInt(COLS)) * TILE_SIZE_F;
        const map_h: f32 = @as(f32, @floatFromInt(ROWS)) * TILE_SIZE_F;
        const off_x: f32 = (screen_w - map_w) / 2;
        const off_y: f32 = (screen_h - map_h) / 2;

        for (0..ROWS) |row| {
            for (0..COLS) |col| {
                const x: f32 = off_x + @as(f32, @floatFromInt(col)) * TILE_SIZE_F;
                const y: f32 = off_y + @as(f32, @floatFromInt(row)) * TILE_SIZE_F;
                const color = if (self.visible[row][col])
                    if ((row + col) % 2 == 0) GRASS_LIGHT else GRASS_DARK
                else
                    FOG_COLOR;
                rl.drawRectangleRec(.{ .x = x, .y = y, .width = TILE_SIZE_F, .height = TILE_SIZE_F }, color);
            }
        }
    }
};

/// Converts a robot_pos (pixel offset from screen center) into tile coordinates.
pub fn tileFromPos(robot_pos: rl.Vector2) struct { col: i32, row: i32 } {
    const half_cols: i32 = @intCast(COLS / 2);
    const half_rows: i32 = @intCast(ROWS / 2);
    // Use floor so negative offsets map to the correct tile (e.g. -1px -> tile -1, not 0)
    const col = half_cols + @as(i32, @intFromFloat(@floor(robot_pos.x / TILE_SIZE_F)));
    const row = half_rows + @as(i32, @intFromFloat(@floor(robot_pos.y / TILE_SIZE_F)));
    return .{ .col = col, .row = row };
}
