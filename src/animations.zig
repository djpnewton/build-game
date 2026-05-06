const std = @import("std");

const rl = @import("raylib");
const gmap = @import("map.zig");

// ── Ripple (tap feedback) ────────────────────────────────────────────────────

const ripple_duration: f32 = 0.5;
var ripple_col: i32 = 0;
var ripple_row: i32 = 0;
var ripple_t: f32 = ripple_duration;

pub fn startRipple(c: i32, r: i32) void {
    ripple_col = c;
    ripple_row = r;
    ripple_t = 0;
}

// ── Chop sweep arc (on the tree tile) ──────────────────────────────────────

const CHOP_DURATION: f32 = 0.28;
var chop_t: f32 = CHOP_DURATION;
var chop_cx: f32 = 0; // tree tile centre in map space
var chop_cy: f32 = 0;

pub fn startChop(tree_col: i32, tree_row: i32) void {
    // Pivot = bottom-left corner of tile
    chop_cx = @as(f32, @floatFromInt(tree_col)) * gmap.TILE_SIZE_F;
    chop_cy = (@as(f32, @floatFromInt(tree_row)) + 1.0) * gmap.TILE_SIZE_F;
    chop_t = 0;
}

// ── Shared update / draw ─────────────────────────────────────────────────────

pub fn update() void {
    const dt = rl.getFrameTime();
    ripple_t += dt;
    if (chop_t < CHOP_DURATION) chop_t += dt;
}

pub fn draw(off_x: f32, off_y: f32) void {
    // Ripple
    if (ripple_t < ripple_duration) {
        const progress = ripple_t / ripple_duration;
        const cx = off_x + @as(f32, @floatFromInt(ripple_col)) * gmap.TILE_SIZE_F + gmap.TILE_SIZE_F * 0.5;
        const cy = off_y + @as(f32, @floatFromInt(ripple_row)) * gmap.TILE_SIZE_F + gmap.TILE_SIZE_F * 0.5;
        const alpha: u8 = @intFromFloat((1.0 - progress) * 200.0);
        const color = rl.Color.init(255, 255, 255, alpha);
        rl.drawCircleLinesV(.{ .x = cx, .y = cy }, progress * gmap.TILE_SIZE_F * 0.7, color);
        rl.drawCircleLinesV(.{ .x = cx, .y = cy }, progress * gmap.TILE_SIZE_F * 0.4, color);
    }

    // Chop — arc pivoting from bottom-left corner, top-left → bottom-right
    if (chop_t < CHOP_DURATION) {
        const progress = chop_t / CHOP_DURATION;
        const cx = off_x + chop_cx;
        const cy = off_y + chop_cy;
        // Radius = tile diagonal so arc touches top-left (-90°) and bottom-right (0°)
        const radius: f32 = gmap.TILE_SIZE_F;
        const fade: f32 = 1.0 - progress * 0.5;

        // Leading edge sweeps from -90° (top-left) to 0° (bottom-right)
        const SWEEP: f32 = 90.0;
        const TAIL: f32 = 60.0;
        const leading = -90.0 + progress * SWEEP;
        const tail_start = @max(leading - TAIL, -90.0);

        // 8 glow segments: deep blue at tail → warm yellow at leading edge
        const N: usize = 8;
        const seg: f32 = (leading - tail_start) / @as(f32, @floatFromInt(N));
        for (0..N) |i| {
            const fi: f32 = @as(f32, @floatFromInt(i));
            const p: f32 = fi / @as(f32, @floatFromInt(N - 1));
            const t0 = tail_start + fi * seg;
            const t1 = t0 + seg;
            const rr: u8 = @intFromFloat(55.0 + p * 200.0);
            const gg: u8 = @intFromFloat(120.0 + p * 80.0);
            const bb: u8 = @intFromFloat(255.0 - p * 220.0);
            const a: u8 = @intFromFloat(fade * (20.0 + p * 215.0));
            rl.drawCircleSector(.{ .x = cx, .y = cy }, radius, t0, t1, 3, rl.Color.init(rr, gg, bb, a));
        }

        // Bright leading blade sliver — cream/white
        const blade_a: u8 = @intFromFloat(fade * 255.0);
        rl.drawCircleSector(.{ .x = cx, .y = cy }, radius, leading - 5.0, leading, 3, rl.Color.init(255, 248, 215, blade_a));

        // Scatter chips around the arc (small sparks)
        const dot_a: u8 = @intFromFloat((1.0 - progress) * 210.0);
        const dc = rl.Color.init(255, 220, 60, dot_a);
        const lead_r = leading * (std.math.pi / 180.0);
        const cl = @cos(lead_r);
        const sl = @sin(lead_r);
        rl.drawCircleV(.{ .x = cx + cl * radius * 1.08, .y = cy + sl * radius * 1.08 }, 1.5, dc);
        rl.drawCircleV(.{ .x = cx + cl * radius * 1.15, .y = cy + sl * radius * 1.15 }, 1.0, dc);
        const mid_r = (leading - TAIL * 0.4) * (std.math.pi / 180.0);
        rl.drawCircleV(.{ .x = cx + @cos(mid_r) * radius * 1.05, .y = cy + @sin(mid_r) * radius * 1.05 }, 1.0, dc);
    }
}
