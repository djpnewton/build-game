const rl = @import("raylib");
const gmap = @import("map.zig");

const TRUNK_COLOR = rl.Color.init(101, 67, 33, 255);
const FOLIAGE_DARK = rl.Color.init(34, 100, 34, 255);
const FOLIAGE_LIGHT = rl.Color.init(60, 140, 60, 255);
const ROCK_DARK = rl.Color.init(110, 105, 100, 255);
const ROCK_MID = rl.Color.init(138, 132, 125, 255);
const ROCK_LIGHT = rl.Color.init(175, 170, 163, 255);
const ROCK_CRACK = rl.Color.init(75, 70, 66, 255);

pub const Kind = enum { tree, rock, rock_large };

const Object = struct { col: i32, row: i32, kind: Kind };

const MAX_OBJECTS = 512;

pub const ObjectMap = struct {
    objects: [MAX_OBJECTS]Object = undefined,
    count: usize = 0,

    pub fn place(self: *ObjectMap, map: *gmap.Map, col: i32, row: i32, kind: Kind) void {
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
        } else {
            if (map.isBlocked(col, row)) return;
            map.blocked[@intCast(row)][@intCast(col)] = true;
        }
        self.objects[self.count] = .{ .col = col, .row = row, .kind = kind };
        self.count += 1;
    }

    pub fn draw(self: ObjectMap, map: *const gmap.Map) void {
        const screen_w: f32 = @floatFromInt(rl.getRenderWidth());
        const screen_h: f32 = @floatFromInt(rl.getRenderHeight());
        const off_x: f32 = (screen_w - @as(f32, @floatFromInt(gmap.COLS)) * gmap.TILE_SIZE_F) / 2;
        const off_y: f32 = (screen_h - @as(f32, @floatFromInt(gmap.ROWS)) * gmap.TILE_SIZE_F) / 2;

        for (self.objects[0..self.count]) |obj| {
            if (!map.visible[@intCast(obj.row)][@intCast(obj.col)]) continue;
            const x = off_x + @as(f32, @floatFromInt(obj.col)) * gmap.TILE_SIZE_F;
            const y = off_y + @as(f32, @floatFromInt(obj.row)) * gmap.TILE_SIZE_F;
            switch (obj.kind) {
                .tree => drawTree(x, y),
                .rock => drawRock(x, y),
                .rock_large => drawRockLarge(x, y),
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
