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

pub const Kind = enum { tree, rock, rock_large, stairs_down, stairs_up };

const Object = struct { col: i32, row: i32, kind: Kind };

const MAX_OBJECTS = 512;

pub const ObjectMap = struct {
    objects: [MAX_OBJECTS]Object = undefined,
    count: usize = 0,

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
        } else if (kind == .stairs_down or kind == .stairs_up) {
            // Non-blocking — just a visual marker.
            if (map.isBlocked(col, row)) return;
        } else {
            if (map.isBlocked(col, row)) return;
            map.blocked[@intCast(row)][@intCast(col)] = true;
        }
        self.objects[self.count] = .{ .col = col, .row = row, .kind = kind };
        self.count += 1;
    }

    pub fn draw(self: ObjectMap, map: *const gmap.TileMap, off_x: f32, off_y: f32) void {
        for (self.objects[0..self.count]) |obj| {
            if (!map.visible[@intCast(obj.row)][@intCast(obj.col)]) continue;
            const x = off_x + @as(f32, @floatFromInt(obj.col)) * gmap.TILE_SIZE_F;
            const y = off_y + @as(f32, @floatFromInt(obj.row)) * gmap.TILE_SIZE_F;
            switch (obj.kind) {
                .tree => drawTree(x, y),
                .rock => drawRock(x, y),
                .rock_large => drawRockLarge(x, y),
                .stairs_down => drawStairsDown(x, y),
                .stairs_up => drawStairsUp(x, y),
            }
        }
    }
};

fn drawTree(x: f32, y: f32) void {
    const cx: i32 = @intFromFloat(x + gmap.TILE_SIZE_F * 0.5);
    const cy: i32 = @intFromFloat(y + gmap.TILE_SIZE_F * 0.5);
    // Trunk: small brown rectangle at the bottom-centre of the tile
    rl.drawRectangle(cx - 3, cy + 5, 6, 9, TRUNK_COLOR);
    // Foliage: two circles for a bit of depth
    rl.drawCircle(cx, cy - 1, 11, FOLIAGE_DARK);
    rl.drawCircle(cx, cy - 3, 8, FOLIAGE_LIGHT);
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
