const std = @import("std");
const rl = @import("raylib");

const gmap = @import("map.zig");
const input = @import("input.zig");
const ut = @import("utils.zig");

const MOVE_SPEED: f32 = 4.0;
const NUM_FRAMES = 6;
const NUM_DIRECTIONS = 8;
const FRAMES_SPEED = 8;

pub const Dir = enum(u8) {
    down = 0,
    down_left,
    left,
    up_left,
    up,
    up_right,
    right,
    down_right,
};

pub const Robot = struct {
    pos: rl.Vector2 = .{ .x = 0, .y = 0 },
    target: rl.Vector2 = .{ .x = 0, .y = 0 },
    dir: Dir = .down,
    frame: i32 = 0,
    frames_counter: i32 = 0,
    tex_static: rl.Texture,
    tex_walk: rl.Texture,

    pub fn load() !Robot {
        const tex_static = try rl.loadTexture("resources/sprites/robot_static.png");
        errdefer rl.unloadTexture(tex_static);
        const tex_walk = try rl.loadTexture("resources/sprites/robot_walk.png");
        return .{ .tex_static = tex_static, .tex_walk = tex_walk };
    }

    pub fn unload(self: Robot) void {
        rl.unloadTexture(self.tex_static);
        rl.unloadTexture(self.tex_walk);
    }

    /// Updates movement and animation. Returns the current tile position.
    pub fn update(self: *Robot, map: *const gmap.Map) gmap.TilePos {
        const dx_rem = self.target.x - self.pos.x;
        const dy_rem = self.target.y - self.pos.y;
        const at_target = @abs(dx_rem) < MOVE_SPEED and @abs(dy_rem) < MOVE_SPEED;

        if (at_target) {
            self.pos = self.target;
            const inp = input.update();
            const step = gmap.TILE_SIZE_F;
            var new_target = self.target;
            if (inp.down and inp.left) {
                self.dir = .down_left;
                new_target.x -= step;
                new_target.y += step;
            } else if (inp.down and inp.right) {
                self.dir = .down_right;
                new_target.x += step;
                new_target.y += step;
            } else if (inp.up and inp.left) {
                self.dir = .up_left;
                new_target.x -= step;
                new_target.y -= step;
            } else if (inp.up and inp.right) {
                self.dir = .up_right;
                new_target.x += step;
                new_target.y -= step;
            } else if (inp.down) {
                self.dir = .down;
                new_target.y += step;
            } else if (inp.up) {
                self.dir = .up;
                new_target.y -= step;
            } else if (inp.left) {
                self.dir = .left;
                new_target.x -= step;
            } else if (inp.right) {
                self.dir = .right;
                new_target.x += step;
            }
            const max_x = @as(f32, @floatFromInt(gmap.COLS / 2)) * gmap.TILE_SIZE_F;
            const max_y = @as(f32, @floatFromInt(gmap.ROWS / 2)) * gmap.TILE_SIZE_F;
            new_target.x = std.math.clamp(new_target.x, -max_x, max_x - gmap.TILE_SIZE_F);
            new_target.y = std.math.clamp(new_target.y, -max_y, max_y - gmap.TILE_SIZE_F);
            // Cancel move if the target tile is blocked by an object
            if (new_target.x != self.target.x or new_target.y != self.target.y) {
                const t = gmap.tileFromPos(new_target);
                if (map.isBlocked(t.col, t.row)) {
                    new_target = self.target;
                    self.dir = self.dir; // keep facing direction
                }
            }
            self.target = new_target;
        }

        // Slide toward target
        const moving = self.pos.x != self.target.x or self.pos.y != self.target.y;
        if (moving) {
            const tdx = self.target.x - self.pos.x;
            const tdy = self.target.y - self.pos.y;
            const dist = @sqrt(tdx * tdx + tdy * tdy);
            if (dist <= MOVE_SPEED) {
                self.pos = self.target;
            } else {
                self.pos.x += tdx / dist * MOVE_SPEED;
                self.pos.y += tdy / dist * MOVE_SPEED;
            }
        }

        // Animate
        const still = self.pos.x == self.target.x and self.pos.y == self.target.y;
        if (still) {
            self.frame = 0;
            self.frames_counter = 0;
        } else {
            self.frames_counter += 1;
            if (self.frames_counter >= 60 / FRAMES_SPEED) {
                self.frames_counter = 0;
                self.frame += 1;
                if (self.frame >= NUM_FRAMES) self.frame = 0;
            }
        }

        return gmap.tileFromPos(self.pos);
    }

    pub fn draw(self: Robot, off_x: f32, off_y: f32) void {
        const sprite_w: f32 = ut.i32tof32(self.tex_static.width);
        const sprite_h: f32 = ut.i32tof32(self.tex_static.height) / NUM_DIRECTIONS;
        // Map origin in screen space: off_x/off_y is the top-left of tile (0,0),
        // the robot coordinate origin is the centre of the map.
        const origin_x: f32 = off_x + @as(f32, @floatFromInt(gmap.COLS / 2)) * gmap.TILE_SIZE_F;
        const origin_y: f32 = off_y + @as(f32, @floatFromInt(gmap.ROWS / 2)) * gmap.TILE_SIZE_F;
        const draw_pos = rl.Vector2{
            .x = origin_x + self.pos.x + (gmap.TILE_SIZE_F - sprite_w) / 2,
            .y = origin_y + self.pos.y + (gmap.TILE_SIZE_F - sprite_h) / 2,
        };
        const dir_f: f32 = @floatFromInt(@intFromEnum(self.dir));
        const frame_rec = rl.Rectangle{
            .x = ut.i32tof32(self.frame) * sprite_w,
            .y = dir_f * sprite_h,
            .width = sprite_w,
            .height = sprite_h,
        };
        const still = self.pos.x == self.target.x and self.pos.y == self.target.y;
        rl.drawTextureRec(if (still) self.tex_static else self.tex_walk, frame_rec, draw_pos, .white);
    }
};
