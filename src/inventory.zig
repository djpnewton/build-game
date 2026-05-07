const std = @import("std");
const rl = @import("raylib");
const gmap = @import("map.zig");

pub var wood: u32 = 0;
pub var stone: u32 = 0;
pub var has_key: bool = false;

// ── Floating +N popups ────────────────────────────────────────────────────────

const MAX_POPUPS = 8;
const POPUP_DURATION: f32 = 1.1;

const Popup = struct {
    n: u32,
    col: i32, // tile position in map space
    row: i32,
    t: f32 = 0,
};

var popups: [MAX_POPUPS]Popup = undefined;
var popup_count: usize = 0;

fn spawnPopup(n: u32, col: i32, row: i32) void {
    if (popup_count < MAX_POPUPS) {
        popups[popup_count] = .{ .n = n, .col = col, .row = row };
        popup_count += 1;
    } else {
        for (1..MAX_POPUPS) |i| popups[i - 1] = popups[i];
        popups[MAX_POPUPS - 1] = .{ .n = n, .col = col, .row = row };
    }
}

pub fn addWood(n: u32, col: i32, row: i32) void {
    wood += n;
    spawnPopup(n, col, row);
}

pub fn addStone(n: u32, col: i32, row: i32) void {
    stone += n;
    spawnPopup(n, col, row);
}

pub fn update() void {
    const dt = rl.getFrameTime();
    var i: usize = 0;
    while (i < popup_count) {
        popups[i].t += dt;
        if (popups[i].t >= POPUP_DURATION) {
            popups[i] = popups[popup_count - 1];
            popup_count -= 1;
        } else {
            i += 1;
        }
    }
}

// ── Layout helpers ────────────────────────────────────────────────────────────

const PAD: f32 = 10;
const ROW_H: f32 = 22;
const ICON_W: f32 = 18;

// ── Draw ──────────────────────────────────────────────────────────────────────

pub fn draw() void {
    const num_rows: f32 = if (has_key) 3.0 else 2.0;
    const py = @as(f32, @floatFromInt(rl.getScreenHeight())) - PAD - ROW_H * num_rows - 6;

    // Background panel
    rl.drawRectangleRounded(
        .{ .x = PAD - 4, .y = py - 4, .width = 72, .height = ROW_H * num_rows + 10 },
        0.3,
        4,
        rl.Color.init(0, 0, 0, 110),
    );

    var cur_y = py;

    // Key row (topmost when held)
    if (has_key) {
        drawMiniKey(
            @intFromFloat(PAD + ICON_W * 0.5),
            @intFromFloat(cur_y + ROW_H * 0.5),
        );
        rl.drawText("Key", @intFromFloat(PAD + ICON_W + 2), @intFromFloat(cur_y + 4), 14, rl.Color.init(230, 195, 50, 255));
        cur_y += ROW_H;
    }

    // Wood row
    {
        drawMiniTree(@intFromFloat(PAD + ICON_W * 0.5), @intFromFloat(cur_y + ROW_H * 0.5 - 1));
        var buf: [16:0]u8 = undefined;
        const s = std.fmt.bufPrintZ(&buf, "{d}", .{wood}) catch "?";
        rl.drawText(s, @intFromFloat(PAD + ICON_W + 2), @intFromFloat(cur_y + 4), 14, rl.Color.init(230, 210, 160, 255));
        cur_y += ROW_H;
    }

    // Stone row
    {
        drawMiniRock(@intFromFloat(PAD + ICON_W * 0.5), @intFromFloat(cur_y + ROW_H * 0.5 + 1));
        var buf: [16:0]u8 = undefined;
        const s = std.fmt.bufPrintZ(&buf, "{d}", .{stone}) catch "?";
        rl.drawText(s, @intFromFloat(PAD + ICON_W + 2), @intFromFloat(cur_y + 4), 14, rl.Color.init(190, 185, 175, 255));
    }
}

pub fn drawPopups(off_x: f32, off_y: f32) void {
    for (popups[0..popup_count]) |p| {
        const prog = p.t / POPUP_DURATION;
        const alpha: u8 = @intFromFloat((1.0 - prog) * 230.0);
        const rise: f32 = prog * 28.0;
        const sx: f32 = off_x + (@as(f32, @floatFromInt(p.col)) + 0.5) * gmap.TILE_SIZE_F;
        const sy: f32 = off_y + @as(f32, @floatFromInt(p.row)) * gmap.TILE_SIZE_F - rise;
        var buf: [16:0]u8 = undefined;
        const s = std.fmt.bufPrintZ(&buf, "+{d}", .{p.n}) catch "+?";
        const tw = rl.measureText(s, 14);
        const sx_i: i32 = @intFromFloat(sx);
        const sy_i: i32 = @intFromFloat(sy);
        // Shadow
        rl.drawText(s, sx_i - @divFloor(tw, 2) + 1, sy_i + 1, 14, rl.Color.init(0, 0, 0, @intFromFloat(@as(f32, @floatFromInt(alpha)) * 0.5)));
        rl.drawText(s, sx_i - @divFloor(tw, 2), sy_i, 14, rl.Color.init(255, 230, 80, alpha));
    }
}

// ── Mini icons ────────────────────────────────────────────────────────────────

fn drawMiniTree(cx: i32, cy: i32) void {
    rl.drawRectangle(cx - 2, cy + 3, 4, 5, rl.Color.init(101, 67, 33, 255));
    rl.drawCircle(cx, cy - 1, 6, rl.Color.init(34, 100, 34, 255));
    rl.drawCircle(cx, cy - 2, 4, rl.Color.init(60, 140, 60, 255));
}

fn drawMiniRock(cx: i32, cy: i32) void {
    rl.drawEllipse(cx, cy, 7, 5, rl.Color.init(110, 105, 100, 255));
    rl.drawEllipse(cx + 1, cy - 1, 4, 3, rl.Color.init(138, 132, 125, 255));
    rl.drawEllipse(cx - 1, cy - 2, 2, 1, rl.Color.init(175, 170, 163, 255));
}

fn drawMiniKey(cx: i32, cy: i32) void {
    const GOLD = rl.Color.init(210, 175, 40, 255);
    const GOLD_DARK = rl.Color.init(145, 115, 20, 255);
    // Handle ring
    rl.drawCircle(cx - 4, cy - 0, 4, GOLD_DARK);
    rl.drawCircle(cx - 4, cy - 0, 3, GOLD);
    rl.drawCircle(cx - 4, cy - 0, 1, rl.Color.init(20, 18, 12, 255));
    // Shaft
    rl.drawRectangle(cx - 3, cy - 1, 10, 2, GOLD_DARK);
    rl.drawRectangle(cx - 2, cy + 0, 8, 1, GOLD);
    // Teeth
    rl.drawRectangle(cx + 3, cy + 1, 2, 2, GOLD_DARK);
    rl.drawRectangle(cx + 6, cy + 1, 2, 1, GOLD_DARK);
}
