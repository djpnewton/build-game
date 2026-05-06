const std = @import("std");
const rl = @import("raylib");
const gmap = @import("map.zig");

pub var wood: u32 = 0;
pub var stone: u32 = 0;

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

fn panelY() f32 {
    return @as(f32, @floatFromInt(rl.getScreenHeight())) - PAD - ROW_H * 2 - 6;
}

fn woodIconPos() [2]f32 {
    return .{ PAD, panelY() };
}

fn stoneIconPos() [2]f32 {
    return .{ PAD, panelY() + ROW_H };
}

// ── Draw ──────────────────────────────────────────────────────────────────────

pub fn draw() void {
    const py = panelY();

    // Background panel
    rl.drawRectangleRounded(
        .{ .x = PAD - 4, .y = py - 4, .width = 72, .height = ROW_H * 2 + 10 },
        0.3,
        4,
        rl.Color.init(0, 0, 0, 110),
    );

    // Wood row
    {
        const pos = woodIconPos();
        drawMiniTree(@intFromFloat(pos[0] + ICON_W * 0.5), @intFromFloat(pos[1] + ROW_H * 0.5 - 1));
        var buf: [16:0]u8 = undefined;
        const s = std.fmt.bufPrintZ(&buf, "{d}", .{wood}) catch "?";
        rl.drawText(s, @intFromFloat(pos[0] + ICON_W + 2), @intFromFloat(pos[1] + 4), 14, rl.Color.init(230, 210, 160, 255));
    }

    // Stone row
    {
        const pos = stoneIconPos();
        drawMiniRock(@intFromFloat(pos[0] + ICON_W * 0.5), @intFromFloat(pos[1] + ROW_H * 0.5 + 1));
        var buf: [16:0]u8 = undefined;
        const s = std.fmt.bufPrintZ(&buf, "{d}", .{stone}) catch "?";
        rl.drawText(s, @intFromFloat(pos[0] + ICON_W + 2), @intFromFloat(pos[1] + 4), 14, rl.Color.init(190, 185, 175, 255));
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
