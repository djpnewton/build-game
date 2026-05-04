const rl = @import("raylib");
const gmap = @import("map.zig");
const robot_mod = @import("robot.zig");

const FADE_FRAMES: f32 = 3000;
const MAX_STEPS = 256;
const DOT_RADIUS: f32 = 1.5;
const DOTS_PER_HALF = 3;
const FOOT_OFFSET_Y: f32 = 8.0;

const Step = struct {
    col: i32,
    row: i32,
    entry_dir: robot_mod.Dir,
    exit_dir: robot_mod.Dir,
    age: f32,
    exited: bool,
};

// Pixel offset from tile centre to the exit edge in the given direction.
// Diagonals naturally produce (±h, ±h) which already reaches the corner.
fn edgeVec(dir: robot_mod.Dir) rl.Vector2 {
    const h = gmap.TILE_SIZE_F * 0.5;
    return switch (dir) {
        .down => .{ .x = 0, .y = h },
        .down_right => .{ .x = h, .y = h },
        .right => .{ .x = h, .y = 0 },
        .up_right => .{ .x = h, .y = -h },
        .up => .{ .x = 0, .y = -h },
        .up_left => .{ .x = -h, .y = -h },
        .left => .{ .x = -h, .y = 0 },
        .down_left => .{ .x = -h, .y = h },
    };
}

fn drawDots(from: rl.Vector2, to: rl.Vector2, n: usize, seed: u32, fade: f32, alpha: u8) void {
    const dx = to.x - from.x;
    const dy = to.y - from.y;
    const len = @sqrt(dx * dx + dy * dy);
    const px = if (len > 0) dx / len else 0; // unit vec along segment
    const py = if (len > 0) dy / len else 0;
    const nf: f32 = @floatFromInt(n);
    for (0..n) |di| {
        const js: u32 = seed *% 2246822519 +% @as(u32, @intCast(di)) *% 2654435761;
        const t = (@as(f32, @floatFromInt(di)) + @as(f32, @floatFromInt(js % 997)) / 997.0) / nf;
        const js2 = js *% 374761393;
        const jitter: f32 = (@as(f32, @floatFromInt(js2 % 7)) - 3.0) * 0.5;
        rl.drawCircleV(.{
            .x = from.x + dx * t + (-py * jitter),
            .y = from.y + dy * t + (px * jitter),
        }, DOT_RADIUS * fade, rl.Color.init(255, 255, 200, alpha));
    }
}

pub const Footsteps = struct {
    steps: [MAX_STEPS]Step = undefined,
    count: usize = 0,
    last_tile: gmap.TilePos = .{ .col = -9999, .row = -9999 },

    pub fn resetLastTile(self: *Footsteps) void {
        self.last_tile = .{ .col = -9999, .row = -9999 };
    }

    pub fn update(self: *Footsteps, tile: gmap.TilePos, dir: robot_mod.Dir) void {
        const is_diagonal = switch (dir) {
            .down_right, .up_right, .up_left, .down_left => true,
            else => false,
        };
        const col_changed = tile.col != self.last_tile.col;
        const row_changed = tile.row != self.last_tile.row;
        // For diagonals require both axes to cross so we don't record a spurious
        // intermediate cardinal tile when x and y boundaries cross in different frames.
        const tile_changed = if (is_diagonal) col_changed and row_changed else col_changed or row_changed;

        if (tile_changed) {
            if (self.count > 0) {
                self.steps[self.count - 1].exited = true;
                self.steps[self.count - 1].exit_dir = dir;
            }
            self.last_tile = tile;
            const new_step = Step{ .col = tile.col, .row = tile.row, .entry_dir = dir, .exit_dir = dir, .age = 0, .exited = false };
            if (self.count < MAX_STEPS) {
                self.steps[self.count] = new_step;
                self.count += 1;
            } else {
                for (1..MAX_STEPS) |i| self.steps[i - 1] = self.steps[i];
                self.steps[MAX_STEPS - 1] = new_step;
            }
        }
        for (self.steps[0..self.count]) |*s| s.age += 1;
        var keep: usize = 0;
        for (self.steps[0..self.count]) |s| {
            if (s.age < FADE_FRAMES) {
                self.steps[keep] = s;
                keep += 1;
            }
        }
        self.count = keep;
    }

    pub fn draw(self: Footsteps, off_x: f32, off_y: f32) void {
        for (self.steps[0..self.count]) |s| {
            const fade = 1.0 - (s.age / FADE_FRAMES);
            const alpha: u8 = @intFromFloat(fade * 210);
            const cx = off_x + (@as(f32, @floatFromInt(s.col)) + 0.5) * gmap.TILE_SIZE_F;
            const cy = off_y + (@as(f32, @floatFromInt(s.row)) + 0.5) * gmap.TILE_SIZE_F + FOOT_OFFSET_Y;
            const center = rl.Vector2{ .x = cx, .y = cy };
            const seed: u32 = @as(u32, @bitCast(s.col *% 73856093 +% s.row *% 19349663)) ^ @as(u32, @intFromEnum(s.entry_dir)) *% 83492791;
            const ev = edgeVec(s.entry_dir);
            const entry_pt = rl.Vector2{ .x = cx - ev.x, .y = cy - ev.y };
            if (!s.exited) {
                drawDots(entry_pt, center, DOTS_PER_HALF, seed, fade, alpha);
            } else if (s.entry_dir == s.exit_dir) {
                const exit_pt = rl.Vector2{ .x = cx + ev.x, .y = cy + ev.y };
                drawDots(entry_pt, exit_pt, DOTS_PER_HALF * 2, seed, fade, alpha);
            } else {
                drawDots(entry_pt, center, DOTS_PER_HALF, seed, fade, alpha);
                const xv = edgeVec(s.exit_dir);
                const exit_pt = rl.Vector2{ .x = cx + xv.x, .y = cy + xv.y };
                drawDots(center, exit_pt, DOTS_PER_HALF, seed ^ @as(u32, @intFromEnum(s.exit_dir)) *% 374761393, fade, alpha);
            }
        }
    }
};
