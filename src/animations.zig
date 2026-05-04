const rl = @import("raylib");

const gmap = @import("map.zig");

const duration: f32 = 0.5;

var col: i32 = 0;
var row: i32 = 0;
var t: f32 = duration; // >= duration means inactive

pub fn startRipple(c: i32, r: i32) void {
    col = c;
    row = r;
    t = 0;
}

pub fn update() void {
    t += rl.getFrameTime();
}

pub fn draw(off_x: f32, off_y: f32) void {
    if (t >= duration) return;
    const progress = t / duration;
    const cx = off_x + @as(f32, @floatFromInt(col)) * gmap.TILE_SIZE_F + gmap.TILE_SIZE_F * 0.5;
    const cy = off_y + @as(f32, @floatFromInt(row)) * gmap.TILE_SIZE_F + gmap.TILE_SIZE_F * 0.5;
    const alpha: u8 = @intFromFloat((1.0 - progress) * 200.0);
    const color = rl.Color.init(255, 255, 255, alpha);
    rl.drawCircleLinesV(.{ .x = cx, .y = cy }, progress * gmap.TILE_SIZE_F * 0.7, color);
    rl.drawCircleLinesV(.{ .x = cx, .y = cy }, progress * gmap.TILE_SIZE_F * 0.4, color);
}
