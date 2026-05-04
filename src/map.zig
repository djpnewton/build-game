const std = @import("std");

const rl = @import("raylib");

pub const TILE_SIZE: i32 = 32;
pub const TILE_SIZE_F: f32 = @floatFromInt(TILE_SIZE);
pub const COLS: usize = 20;
pub const ROWS: usize = 20;

const GRASS_LIGHT = rl.Color.init(85, 170, 85, 255);
const GRASS_DARK = rl.Color.init(70, 145, 70, 255);
const FOG_COLOR = rl.Color.init(0, 0, 0, 255);

/// Abstract tile grid used by all map types.  Holds visibility + collision
/// data and the logic that operates on it.  Drawing is left to each scene.
pub const TileMap = struct {
    visible: [ROWS][COLS]bool = std.mem.zeroes([ROWS][COLS]bool),
    blocked: [ROWS][COLS]bool = std.mem.zeroes([ROWS][COLS]bool),

    pub fn isBlocked(self: *const TileMap, col: i32, row: i32) bool {
        if (col < 0 or col >= COLS or row < 0 or row >= ROWS) return true;
        return self.blocked[@intCast(row)][@intCast(col)];
    }

    /// Reveal all tiles within `radius` tiles of (tile_col, tile_row).
    pub fn revealAround(self: *TileMap, tile_col: i32, tile_row: i32, radius: i32) void {
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
};

/// Overworld scene: grassy outdoor map.  Wraps TileMap and owns its drawing.
pub const OverworldMap = struct {
    map: TileMap = .{},

    pub fn draw(self: OverworldMap, off_x: f32, off_y: f32) void {
        const screen_w: f32 = @floatFromInt(rl.getRenderWidth());
        const screen_h: f32 = @floatFromInt(rl.getRenderHeight());
        for (0..ROWS) |row| {
            for (0..COLS) |col| {
                const x: f32 = off_x + @as(f32, @floatFromInt(col)) * TILE_SIZE_F;
                const y: f32 = off_y + @as(f32, @floatFromInt(row)) * TILE_SIZE_F;
                if (x + TILE_SIZE_F < 0 or x > screen_w or y + TILE_SIZE_F < 0 or y > screen_h) continue;
                const color = if (self.map.visible[row][col])
                    if ((row + col) % 2 == 0) GRASS_LIGHT else GRASS_DARK
                else
                    FOG_COLOR;
                rl.drawRectangleRec(.{ .x = x, .y = y, .width = TILE_SIZE_F, .height = TILE_SIZE_F }, color);
            }
        }
    }
};

pub const TilePos = struct { col: i32, row: i32 };

/// Converts a robot_pos (pixel offset from map origin) into tile coordinates.
/// Uses the robot's centre (pos + half tile) so leftward/upward movement
/// triggers the tile change at the same visual mid-point as rightward/downward.
pub fn tileFromPos(robot_pos: rl.Vector2) TilePos {
    const half_cols: i32 = @intCast(COLS / 2);
    const half_rows: i32 = @intCast(ROWS / 2);
    const cx = robot_pos.x + TILE_SIZE_F * 0.5;
    const cy = robot_pos.y + TILE_SIZE_F * 0.5;
    const col = half_cols + @as(i32, @intFromFloat(@floor(cx / TILE_SIZE_F)));
    const row = half_rows + @as(i32, @intFromFloat(@floor(cy / TILE_SIZE_F)));
    return TilePos{ .col = col, .row = row };
}

// ─── Dungeon ──────────────────────────────────────────────────────────────────

/// Tile on the overworld where the dungeon entrance is placed.
pub const overworld_entrance: TilePos = .{ .col = 14, .row = 14 };
/// Tile in the dungeon where the robot spawns (also the exit stairs).
pub const dungeon_spawn: TilePos = .{ .col = 1, .row = 1 };

const CELL_COUNT: usize = 9; // 9×9 cells → tiles 1,3,5…17 per axis
const NCELLS: i32 = CELL_COUNT;

const WALL_COLOR = rl.Color.init(58, 54, 49, 255);
const WALL_MORTAR = rl.Color.init(26, 24, 22, 255);
const WALL_BRICK_HI = rl.Color.init(76, 71, 63, 255);
const WALL_BRICK_DARK = rl.Color.init(42, 39, 35, 255);
const WALL_TOP = rl.Color.init(88, 82, 73, 255);
const FLOOR_EVEN = rl.Color.init(92, 87, 81, 255);
const FLOOR_ODD = rl.Color.init(82, 77, 71, 255);

/// Draws a single wall tile with a staggered brick pattern.  Bricks are 15×7 px
/// with 1 px mortar seams on the top/left of each slot (8×16 px slots).
/// The stagger alternates every brick sub-row and is continuous across tile edges.
fn drawWallTile(xi: i32, yi: i32, col: usize, row: usize) void {
    // Fill with mortar colour – seams show through wherever no brick is drawn.
    rl.drawRectangle(xi, yi, TILE_SIZE, TILE_SIZE, WALL_MORTAR);

    const bh: i32 = 8; // brick slot height  (1 mortar + 7 brick)
    const bw: i32 = 16; // brick slot width   (1 mortar + 15 brick)

    // Per-tile hash for colour variation across bricks.
    var h: u32 = @as(u32, @intCast(col)) *% 2246822519;
    h ^= @as(u32, @intCast(row)) *% 2654435761;
    h = (h ^ (h >> 13)) *% 1274126177;
    h ^= h >> 16;

    for (0..4) |br| {
        const bri: i32 = @intCast(br);
        const brick_y = yi + bri * bh + 1; // +1 for top mortar row
        // Stagger alternates each sub-row; depends only on (row+br) parity
        // so the seam pattern is seamless across adjacent wall tiles.
        const stagger: i32 = if ((row + br) % 2 == 0) 0 else @divExact(bw, 2);

        var bc: i32 = -1;
        while (bc * bw - stagger < TILE_SIZE) : (bc += 1) {
            const brick_x = xi + bc * bw - stagger + 1; // +1 for left mortar
            const clip_l = @max(brick_x, xi);
            const clip_r = @min(brick_x + bw - 1, xi + TILE_SIZE);
            if (clip_r <= clip_l) continue;

            const bk: u32 = @as(u32, @intCast(br)) * 8 +
                @as(u32, @intCast(bc + 1)); // bc+1 ≥ 0
            const brick_hash = h ^ (bk *% 374761393);
            const color = switch (brick_hash & 7) {
                0, 1 => WALL_BRICK_HI,
                6 => WALL_BRICK_DARK,
                else => WALL_COLOR,
            };
            rl.drawRectangle(clip_l, brick_y, clip_r - clip_l, bh - 1, color);
        }
    }

    // Top-face cap – gives illusion of wall thickness in top-down view.
    rl.drawRectangle(xi, yi, TILE_SIZE, 2, WALL_TOP);
}

pub const DungeonMap = struct {
    map: TileMap = .{},
    generated: bool = false,

    pub fn ensureGenerated(self: *DungeonMap) void {
        if (self.generated) return;
        self.generated = true;

        // Start with everything walled off.
        for (0..ROWS) |r| {
            for (0..COLS) |c| self.map.blocked[r][c] = true;
        }

        // Clear the 9×9 cell positions (odd, odd).
        for (0..CELL_COUNT) |cr| {
            for (0..CELL_COUNT) |cc| {
                self.map.blocked[1 + cr * 2][1 + cc * 2] = false;
            }
        }

        // Iterative DFS maze carving (fixed seed → deterministic map).
        var visited: [CELL_COUNT][CELL_COUNT]bool = std.mem.zeroes([CELL_COUNT][CELL_COUNT]bool);
        var stack: [CELL_COUNT * CELL_COUNT][2]u8 = undefined;
        var stack_len: usize = 0;
        var rng = std.Random.DefaultPrng.init(77321);
        const rand = rng.random();

        visited[0][0] = true;
        stack[0] = .{ 0, 0 };
        stack_len = 1;

        const deltas = [4][2]i32{ .{ 0, -1 }, .{ 0, 1 }, .{ -1, 0 }, .{ 1, 0 } };

        while (stack_len > 0) {
            const cur = stack[stack_len - 1];
            const cc: i32 = cur[0];
            const cr: i32 = cur[1];

            var nbrs: [4][2]u8 = undefined;
            var nbr_count: usize = 0;
            for (deltas) |d| {
                const nc = cc + d[0];
                const nr = cr + d[1];
                if (nc < 0 or nc >= NCELLS or nr < 0 or nr >= NCELLS) continue;
                if (visited[@intCast(nr)][@intCast(nc)]) continue;
                nbrs[nbr_count] = .{ @intCast(nc), @intCast(nr) };
                nbr_count += 1;
            }

            if (nbr_count == 0) {
                stack_len -= 1;
            } else {
                const next = nbrs[rand.intRangeLessThan(usize, 0, nbr_count)];
                const tc = 1 + 2 * @as(usize, cur[0]);
                const tr = 1 + 2 * @as(usize, cur[1]);
                const tnc = 1 + 2 * @as(usize, next[0]);
                const tnr = 1 + 2 * @as(usize, next[1]);
                self.map.blocked[(tr + tnr) / 2][(tc + tnc) / 2] = false;

                visited[@intCast(next[1])][@intCast(next[0])] = true;
                stack[stack_len] = next;
                stack_len += 1;
            }
        }
    }

    pub fn draw(self: *const DungeonMap, off_x: f32, off_y: f32) void {
        const screen_w: f32 = @floatFromInt(rl.getRenderWidth());
        const screen_h: f32 = @floatFromInt(rl.getRenderHeight());

        for (0..ROWS) |row| {
            for (0..COLS) |col| {
                const x = off_x + @as(f32, @floatFromInt(col)) * TILE_SIZE_F;
                const y = off_y + @as(f32, @floatFromInt(row)) * TILE_SIZE_F;
                if (x + TILE_SIZE_F < 0 or x > screen_w or y + TILE_SIZE_F < 0 or y > screen_h) continue;

                if (!self.map.visible[row][col]) {
                    rl.drawRectangleRec(.{ .x = x, .y = y, .width = TILE_SIZE_F, .height = TILE_SIZE_F }, FOG_COLOR);
                } else if (self.map.blocked[row][col]) {
                    drawWallTile(@intFromFloat(x), @intFromFloat(y), col, row);
                } else {
                    const floor_color = if ((row + col) % 2 == 0) FLOOR_EVEN else FLOOR_ODD;
                    rl.drawRectangleRec(.{ .x = x, .y = y, .width = TILE_SIZE_F, .height = TILE_SIZE_F }, floor_color);
                }
            }
        }
    }
};
