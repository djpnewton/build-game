const rl = @import("raylib");

const gmap = @import("map.zig");

/// Camera tracks the robot and clamps to map edges.
/// `offset()` returns the screen-space top-left corner of the map (may be negative
/// when the map is larger than the window and the camera has scrolled).
pub const Camera = struct {
    // World position of the camera centre (same coordinate space as robot.pos —
    // offset from the map's own centre).
    x: f32 = 0,
    y: f32 = 0,

    pub fn follow(self: *Camera, target_x: f32, target_y: f32) void {
        const sw: f32 = @floatFromInt(rl.getRenderWidth());
        const sh: f32 = @floatFromInt(rl.getRenderHeight());
        const map_w: f32 = @as(f32, @floatFromInt(gmap.COLS)) * gmap.TILE_SIZE_F;
        const map_h: f32 = @as(f32, @floatFromInt(gmap.ROWS)) * gmap.TILE_SIZE_F;

        // Follow target (centre of the robot's tile)
        self.x = target_x + gmap.TILE_SIZE_F * 0.5;
        self.y = target_y + gmap.TILE_SIZE_F * 0.5;

        const half_sw = sw * 0.5;
        const half_sh = sh * 0.5;
        const map_half_w = map_w * 0.5;
        const map_half_h = map_h * 0.5;

        // Only clamp when the map is larger than the window on that axis;
        // otherwise centre (clamp would assert lower > upper).
        if (map_w > sw) {
            self.x = std.math.clamp(self.x, -map_half_w + half_sw, map_half_w - half_sw);
        } else {
            self.x = 0;
        }
        if (map_h > sh) {
            self.y = std.math.clamp(self.y, -map_half_h + half_sh, map_half_h - half_sh);
        } else {
            self.y = 0;
        }
    }

    /// Top-left pixel of the map in screen space.
    pub fn offset(self: Camera) struct { x: f32, y: f32 } {
        const sw: f32 = @floatFromInt(rl.getRenderWidth());
        const sh: f32 = @floatFromInt(rl.getRenderHeight());
        const map_w: f32 = @as(f32, @floatFromInt(gmap.COLS)) * gmap.TILE_SIZE_F;
        const map_h: f32 = @as(f32, @floatFromInt(gmap.ROWS)) * gmap.TILE_SIZE_F;
        return .{
            .x = sw * 0.5 - map_w * 0.5 - self.x,
            .y = sh * 0.5 - map_h * 0.5 - self.y,
        };
    }
};

const std = @import("std");
