const rl = @import("raylib");

const gmap = @import("map.zig");
const portals = @import("portals.zig");

const TRUNK_COLOR = rl.Color.init(101, 67, 33, 255);
const FOLIAGE_DARK = rl.Color.init(34, 100, 34, 255);
const FOLIAGE_LIGHT = rl.Color.init(60, 140, 60, 255);
const ROCK_DARK = rl.Color.init(110, 105, 100, 255);
const ROCK_MID = rl.Color.init(138, 132, 125, 255);
const ROCK_LIGHT = rl.Color.init(175, 170, 163, 255);
const ROCK_CRACK = rl.Color.init(75, 70, 66, 255);

pub const Kind = enum { tree, rock, rock_large, stairs_down, stairs_up, diamond };

const Object = struct { col: i32, row: i32, kind: Kind, hits: u8 = 0 };

const MAX_OBJECTS = 512;

pub const ObjectMap = struct {
    objects: [MAX_OBJECTS]Object = undefined,
    count: usize = 0,
    cache: rl.RenderTexture2D = undefined,
    cache_loaded: bool = false,
    dirty: bool = true,

    pub fn markDirty(self: *ObjectMap) void {
        self.dirty = true;
    }

    pub fn scatter(self: *ObjectMap, map: *gmap.TileMap) void {
        const half_col: i32 = @intCast(gmap.COLS / 2);
        const half_row: i32 = @intCast(gmap.ROWS / 2);
        var col: i32 = 1;
        while (col < gmap.COLS - 1) : (col += 1) {
            var row: i32 = 1;
            while (row < gmap.ROWS - 1) : (row += 1) {
                // Keep centre clear for robot spawn
                if (@abs(col - half_col) < 4 and @abs(row - half_row) < 4) continue;
                // Keep portal tiles clear
                if ((col == portals.red.col and row == portals.red.row) or
                    (col == portals.blue.col and row == portals.blue.row)) continue;
                // Keep dungeon entrance clear
                if (col == gmap.overworld_entrance.col and row == gmap.overworld_entrance.row) continue;
                // Large rocks (placed first so smaller objects won't spawn on top)
                var g: u32 = @as(u32, @bitCast(col)) *% 2246822519;
                g ^= @as(u32, @bitCast(row)) *% 2654435761;
                g = (g ^ (g >> 13)) *% 1274126177;
                g ^= g >> 16;
                if (g % 18 == 0) self.place(map, col, row, .rock_large);
                // Trees
                var h: u32 = @as(u32, @bitCast(col)) *% 374761393;
                h ^= @as(u32, @bitCast(row)) *% 668265263;
                h = (h ^ (h >> 13)) *% 1274126177;
                h ^= h >> 16;
                if (h % 5 == 0) self.place(map, col, row, .tree);
                // Small rocks
                var r: u32 = @as(u32, @bitCast(col)) *% 668265263;
                r ^= @as(u32, @bitCast(row)) *% 374761393;
                r = (r ^ (r >> 13)) *% 1274126177;
                r ^= r >> 16;
                if (r % 11 == 0) self.place(map, col, row, .rock);
            }
        }
        // Place the dungeon entrance marker (guaranteed clear tile).
        self.place(map, gmap.overworld_entrance.col, gmap.overworld_entrance.row, .stairs_down);
    }

    pub fn place(self: *ObjectMap, map: *gmap.TileMap, col: i32, row: i32, kind: Kind) void {
        if (self.count >= MAX_OBJECTS) return;
        if (col < 0 or col >= gmap.COLS or row < 0 or row >= gmap.ROWS) return;
        if (kind == .rock_large) {
            if (col + 1 >= gmap.COLS or row + 1 >= gmap.ROWS) return;
            if (map.isBlocked(col, row) or map.isBlocked(col + 1, row) or
                map.isBlocked(col, row + 1) or map.isBlocked(col + 1, row + 1)) return;
            map.blocked[@intCast(row)][@intCast(col)] = true;
            map.blocked[@intCast(row)][@intCast(col + 1)] = true;
            map.blocked[@intCast(row + 1)][@intCast(col)] = true;
            map.blocked[@intCast(row + 1)][@intCast(col + 1)] = true;
        } else if (kind == .stairs_down or kind == .stairs_up or kind == .diamond) {
            // Non-blocking — just a visual marker.
            if (map.isBlocked(col, row)) return;
        } else {
            if (map.isBlocked(col, row)) return;
            map.blocked[@intCast(row)][@intCast(col)] = true;
        }
        self.objects[self.count] = .{ .col = col, .row = row, .kind = kind };
        self.count += 1;
        self.dirty = true;
    }

    pub fn findKindAt(self: *const ObjectMap, col: i32, row: i32) ?Kind {
        for (self.objects[0..self.count]) |obj| {
            if (obj.col == col and obj.row == row) return obj.kind;
        }
        return null;
    }

    /// Remove a tree at (col, row) and unblock the tile.
    /// Hit a tree at (col, row). Falls after 3 chops.
    pub fn chop(self: *ObjectMap, map: *gmap.TileMap, col: i32, row: i32) void {
        var i: usize = 0;
        while (i < self.count) : (i += 1) {
            if (self.objects[i].col == col and self.objects[i].row == row and self.objects[i].kind == .tree) {
                self.objects[i].hits += 1;
                self.dirty = true;
                if (self.objects[i].hits >= 3) {
                    map.blocked[@intCast(row)][@intCast(col)] = false;
                    self.objects[i] = self.objects[self.count - 1];
                    self.count -= 1;
                }
                return;
            }
        }
    }

    /// Remove the first object at (col, row).
    pub fn remove(self: *ObjectMap, col: i32, row: i32) void {
        var i: usize = 0;
        while (i < self.count) {
            if (self.objects[i].col == col and self.objects[i].row == row) {
                self.objects[i] = self.objects[self.count - 1];
                self.count -= 1;
            } else {
                i += 1;
            }
        }
        self.dirty = true;
    }

    /// Rebuild the static-object cache into a render texture.
    /// Call before beginDrawing() each frame, after tile caches are updated.
    pub fn updateCache(self: *ObjectMap, map: *const gmap.TileMap) void {
        const map_w: i32 = @as(i32, @intCast(gmap.COLS)) * gmap.TILE_SIZE;
        const map_h: i32 = @as(i32, @intCast(gmap.ROWS)) * gmap.TILE_SIZE;
        if (!self.cache_loaded) {
            self.cache = rl.loadRenderTexture(map_w, map_h) catch unreachable;
            self.cache_loaded = true;
        }
        if (!self.dirty) return;
        self.dirty = false;
        self.cache.begin();
        rl.clearBackground(rl.Color.init(0, 0, 0, 0));
        for (self.objects[0..self.count]) |obj| {
            switch (obj.kind) {
                .diamond, .stairs_down, .stairs_up => continue, // drawn live
                else => {},
            }
            if (!map.visible[@intCast(obj.row)][@intCast(obj.col)]) continue;
            const x = @as(f32, @floatFromInt(obj.col)) * gmap.TILE_SIZE_F;
            const y = @as(f32, @floatFromInt(obj.row)) * gmap.TILE_SIZE_F;
            switch (obj.kind) {
                .tree => drawTree(x, y, obj.hits),
                .rock => drawRock(x, y),
                .rock_large => drawRockLarge(x, y),
                else => unreachable,
            }
        }
        self.cache.end();
    }

    pub fn draw(self: *ObjectMap, map: *const gmap.TileMap, off_x: f32, off_y: f32) void {
        if (self.cache_loaded) {
            const map_w: f32 = @as(f32, @floatFromInt(@as(i32, @intCast(gmap.COLS)) * gmap.TILE_SIZE));
            const map_h: f32 = @as(f32, @floatFromInt(@as(i32, @intCast(gmap.ROWS)) * gmap.TILE_SIZE));
            rl.drawTexturePro(
                self.cache.texture,
                .{ .x = 0, .y = 0, .width = map_w, .height = -map_h },
                .{ .x = off_x, .y = off_y, .width = map_w, .height = map_h },
                .{ .x = 0, .y = 0 },
                0,
                .white,
            );
        }
        // Animated / orientation-sensitive objects drawn live every frame.
        for (self.objects[0..self.count]) |obj| {
            switch (obj.kind) {
                .diamond, .stairs_down, .stairs_up => {},
                else => continue,
            }
            if (!map.visible[@intCast(obj.row)][@intCast(obj.col)]) continue;
            const x = off_x + @as(f32, @floatFromInt(obj.col)) * gmap.TILE_SIZE_F;
            const y = off_y + @as(f32, @floatFromInt(obj.row)) * gmap.TILE_SIZE_F;
            switch (obj.kind) {
                .stairs_down => drawStairsDown(x, y),
                .stairs_up => drawStairsUp(x, y),
                .diamond => drawDiamond(x, y),
                else => unreachable,
            }
        }
    }
};

fn drawTree(x: f32, y: f32, hits: u8) void {
    const cx: i32 = @intFromFloat(x + gmap.TILE_SIZE_F * 0.5);
    const cy: i32 = @intFromFloat(y + gmap.TILE_SIZE_F * 0.5);
    // Foliage — always full size
    rl.drawCircle(cx, cy - 1, 11, FOLIAGE_DARK);
    rl.drawCircle(cx, cy - 3, 8, FOLIAGE_LIGHT);
    // Trunk
    rl.drawRectangle(cx - 3, cy + 5, 6, 9, TRUNK_COLOR);
    // Axe-gash damage marks drawn on top of trunk
    const GASH = rl.Color.init(28, 15, 6, 255);
    const WOOD = rl.Color.init(200, 155, 88, 220);
    if (hits >= 1) {
        // Right-side V notch, mid-trunk
        rl.drawLine(cx + 3, cy + 6, cx, cy + 8, GASH);
        rl.drawLine(cx + 3, cy + 10, cx, cy + 8, GASH);
        rl.drawLine(cx + 1, cy + 7, cx + 3, cy + 8, WOOD);
        rl.drawLine(cx + 1, cy + 9, cx + 3, cy + 8, WOOD);
    }
    if (hits >= 2) {
        // Left-side V notch, lower trunk
        rl.drawLine(cx - 3, cy + 9, cx, cy + 11, GASH);
        rl.drawLine(cx - 3, cy + 13, cx, cy + 11, GASH);
        rl.drawLine(cx - 1, cy + 10, cx - 3, cy + 11, WOOD);
        rl.drawLine(cx - 1, cy + 12, cx - 3, cy + 11, WOOD);
    }
}

fn drawRock(x: f32, y: f32) void {
    const cx: i32 = @intFromFloat(x + gmap.TILE_SIZE_F * 0.5);
    const cy: i32 = @intFromFloat(y + gmap.TILE_SIZE_F * 0.5 + 3);
    rl.drawEllipse(cx, cy + 6, 11, 4, rl.Color.init(0, 0, 0, 50));
    rl.drawEllipse(cx, cy, 11, 9, ROCK_DARK);
    rl.drawEllipse(cx + 1, cy - 1, 7, 6, ROCK_MID);
    rl.drawEllipse(cx - 1, cy - 3, 3, 2, ROCK_LIGHT);
    rl.drawLine(cx + 2, cy - 1, cx + 6, cy + 4, ROCK_CRACK);
    rl.drawLine(cx - 4, cy + 1, cx - 1, cy + 5, ROCK_CRACK);
}

fn drawRockLarge(x: f32, y: f32) void {
    const cx: i32 = @intFromFloat(x + gmap.TILE_SIZE_F);
    const cy: i32 = @intFromFloat(y + gmap.TILE_SIZE_F + 4);
    rl.drawEllipse(cx, cy + 12, 24, 7, rl.Color.init(0, 0, 0, 50));
    rl.drawEllipse(cx, cy, 23, 18, ROCK_DARK);
    rl.drawEllipse(cx + 2, cy - 3, 15, 12, ROCK_MID);
    rl.drawEllipse(cx - 2, cy - 7, 6, 4, ROCK_LIGHT);
    rl.drawLine(cx + 5, cy - 6, cx + 15, cy + 7, ROCK_CRACK);
    rl.drawLine(cx - 9, cy + 2, cx - 3, cy + 11, ROCK_CRACK);
    rl.drawLine(cx + 1, cy - 12, cx + 7, cy - 4, ROCK_CRACK);
    rl.drawLine(cx - 5, cy - 2, cx + 2, cy + 3, ROCK_CRACK);
}

fn drawStairsDown(x: f32, y: f32) void {
    const xi: i32 = @intFromFloat(x);
    const yi: i32 = @intFromFloat(y);
    const ts = gmap.TILE_SIZE;
    rl.drawRectangle(xi + 3, yi + 3, ts - 6, ts - 6, rl.Color.init(28, 26, 23, 255));
    const step = rl.Color.init(155, 138, 100, 255);
    const shadow = rl.Color.init(80, 68, 48, 255);
    for (0..3) |i| {
        const fi: i32 = @intCast(i);
        const m = 3 + fi * 3;
        const sy = yi + 5 + fi * 6;
        rl.drawRectangle(xi + m, sy, ts - m * 2, 4, step);
        rl.drawRectangle(xi + m, sy + 4, ts - m * 2, 1, shadow);
    }
}

fn drawStairsUp(x: f32, y: f32) void {
    const xi: i32 = @intFromFloat(x);
    const yi: i32 = @intFromFloat(y);
    const ts = gmap.TILE_SIZE;
    const step = rl.Color.init(175, 155, 115, 255);
    const shadow = rl.Color.init(100, 85, 60, 255);
    for (0..4) |i| {
        const fi: i32 = @intCast(i);
        const w = ts - 4 - fi * 6;
        const sx = xi + 2 + fi * 3;
        const sy = yi + 4 + fi * 5;
        rl.drawRectangle(sx, sy, w, 4, step);
        rl.drawRectangle(sx, sy + 4, w, 1, shadow);
    }
}

fn drawDiamond(x: f32, y: f32) void {
    const t: f32 = @floatCast(rl.getTime());
    const pulse: f32 = 0.5 + 0.5 * @sin(t * 2.5);
    const cx: i32 = @intFromFloat(x + gmap.TILE_SIZE_F * 0.5);
    const cy: i32 = @intFromFloat(y + gmap.TILE_SIZE_F * 0.5 - 1);

    // Drop shadow
    rl.drawEllipse(cx, cy + 10, 6, 2, rl.Color.init(0, 0, 0, 70));

    // Gem body drawn as rows of rectangles forming a rhombus.
    // Top half: half-width grows 1..7; bottom half shrinks 7..1.
    for (0..7) |i| {
        const fi: i32 = @intCast(i);
        const hw = fi + 1;
        const ry = cy - 7 + fi;
        rl.drawRectangle(cx - hw, ry, hw, 1, rl.Color.init(140, 210, 255, 255)); // left facet (bright)
        rl.drawRectangle(cx, ry, hw, 1, rl.Color.init(40, 130, 210, 255)); // right facet (dark)
    }
    for (0..7) |i| {
        const fi: i32 = @intCast(i);
        const hw = 7 - fi;
        const ry = cy + fi;
        rl.drawRectangle(cx - hw, ry, hw, 1, rl.Color.init(30, 100, 180, 255)); // lower-left (deep)
        rl.drawRectangle(cx, ry, hw, 1, rl.Color.init(70, 155, 225, 255)); // lower-right
    }

    // Animated highlight sparkle on top-left facet
    const sp_a: u8 = @intFromFloat(pulse * 230.0);
    rl.drawRectangle(cx - 4, cy - 5, 3, 2, rl.Color.init(220, 245, 255, sp_a));

    // Pulsing outer glow ring
    const glow_a: u8 = @intFromFloat(pulse * 90.0);
    rl.drawRectangleLines(cx - 8, cy - 8, 16, 16, rl.Color.init(150, 230, 255, glow_a));
}
