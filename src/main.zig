const std = @import("std");
const builtin = @import("builtin");

const rl = @import("raylib");
const rg = @import("raygui");

const ut = @import("utils.zig");
const tmx = @import("tmx.zig");

pub fn main(_: std.process.Init) !void {
    // Initialization
    //--------------------------------------------------------------------------------------

    const screenWidth = 32 * 16;
    const screenHeight = 32 * 16;

    rl.setConfigFlags(rl.ConfigFlags{ .window_resizable = true, .msaa_4x_hint = true });
    rl.initWindow(screenWidth, screenHeight, "build-game");
    defer rl.closeWindow(); // Close window and OpenGL context

    // load map
    var map = tmx.loadFile(std.heap.c_allocator, "resources/grass_tileset_16x16/grass_tileset_map.tmx") catch |err| {
        std.debug.print("Failed to load map: {}\n", .{err});
        return;
    };
    defer map.deinit(std.heap.c_allocator);
    const tileset_textures = tmx.loadTextures(std.heap.c_allocator, map, std.fs.path.dirname("resources/grass_tileset_16x16/grass_tileset_map.tmx") orelse ".") catch |err| {
        std.debug.print("Failed to load map tileset textures: {}\n", .{err});
        return;
    };
    defer std.heap.c_allocator.free(tileset_textures);

    const robot_static = rl.loadTexture("resources/sprites/robot_static.png") catch {
        rl.closeWindow();
        std.debug.print("Failed to load texture robot_static.png\n", .{});
        return;
    };
    defer rl.unloadTexture(robot_static);
    const robot_walk = rl.loadTexture("resources/sprites/robot_walk.png") catch {
        rl.closeWindow();
        std.debug.print("Failed to load texture robot_walk.png\n", .{});
        return;
    };
    defer rl.unloadTexture(robot_walk);
    var current_frame: i32 = 0;
    const num_frames = 6;
    const num_directions = 8;
    var frames_counter: i32 = 0;
    const frames_speed = 8;
    var frame_rec = rl.Rectangle{ .x = 0, .y = 0, .width = ut.i32tof32(robot_static.width), .height = ut.i32tof32(robot_static.height) / num_directions };
    var robot_pos = rl.Vector2{ .x = 0, .y = 0 };

    const dirs = enum(u8) {
        down = 0,
        down_left,
        left,
        up_left,
        up,
        up_right,
        right,
        down_right,
    };
    var current_dir = dirs.down;

    const joy_radius: f32 = 60;
    const joy_knob_radius: f32 = 25;
    var joy_active = false;
    var joy_touch_id: i32 = -1;
    var joy_base = rl.Vector2{ .x = 0, .y = 0 };
    var joy_knob = rl.Vector2{ .x = 0, .y = 0 };
    var joy_dx: f32 = 0;
    var joy_dy: f32 = 0;

    rl.setTargetFPS(60);
    //--------------------------------------------------------------------------------------

    // Main game loop
    while (!rl.windowShouldClose()) { // Detect window close button or ESC key
        // Update
        //----------------------------------------------------------------------------------

        if (comptime builtin.os.tag == .emscripten) {
            const touch_count = rl.getTouchPointCount();
            if (!joy_active and touch_count > 0) {
                for (0..@intCast(touch_count)) |i| {
                    const idx: i32 = @intCast(i);
                    const tp = rl.getTouchPosition(idx);
                    joy_active = true;
                    joy_touch_id = rl.getTouchPointId(idx);
                    joy_base = tp;
                    joy_knob = tp;
                    break;
                }
            }
            if (joy_active) {
                var found = false;
                if (touch_count > 0) {
                    for (0..@intCast(touch_count)) |i| {
                        const idx: i32 = @intCast(i);
                        if (rl.getTouchPointId(idx) == joy_touch_id) {
                            const tp = rl.getTouchPosition(idx);
                            const dx = tp.x - joy_base.x;
                            const dy = tp.y - joy_base.y;
                            const dist = @sqrt(dx * dx + dy * dy);
                            if (dist > joy_radius) {
                                joy_knob.x = joy_base.x + dx / dist * joy_radius;
                                joy_knob.y = joy_base.y + dy / dist * joy_radius;
                            } else {
                                joy_knob = tp;
                            }
                            joy_dx = (joy_knob.x - joy_base.x) / joy_radius;
                            joy_dy = (joy_knob.y - joy_base.y) / joy_radius;
                            found = true;
                            break;
                        }
                    }
                }
                if (!found) {
                    joy_active = false;
                    joy_dx = 0;
                    joy_dy = 0;
                }
            }
        }

        const joy_threshold: f32 = 0.3;
        const key_down = rl.isKeyDown(.down) or joy_dy > joy_threshold;
        const key_up = rl.isKeyDown(.up) or joy_dy < -joy_threshold;
        const key_left = rl.isKeyDown(.left) or joy_dx < -joy_threshold;
        const key_right = rl.isKeyDown(.right) or joy_dx > joy_threshold;
        if (key_down and key_left) {
            current_dir = dirs.down_left;
        } else if (key_down and key_right) {
            current_dir = dirs.down_right;
        } else if (key_up and key_left) {
            current_dir = dirs.up_left;
        } else if (key_up and key_right) {
            current_dir = dirs.up_right;
        } else if (key_down) {
            current_dir = dirs.down;
        } else if (key_up) {
            current_dir = dirs.up;
        } else if (key_left) {
            current_dir = dirs.left;
        } else if (key_right) {
            current_dir = dirs.right;
        }
        const moving = key_down or key_up or key_left or key_right;
        if (!moving) {
            current_frame = 0;
            frame_rec.x = 0;
            frame_rec.y = ut.i32tof32(@intFromEnum(current_dir)) * ut.i32tof32(robot_static.height) / num_directions;
        } else {
            frames_counter += 1;
            if (frames_counter >= (60 / frames_speed)) {
                frames_counter = 0;
                current_frame += 1;
                if (current_frame >= num_frames) {
                    current_frame = 0;
                }
                frame_rec.x = ut.i32tof32(current_frame) * ut.i32tof32(robot_static.width);
                frame_rec.y = ut.i32tof32(@intFromEnum(current_dir)) * ut.i32tof32(robot_static.height) / num_directions;
            }
            // update robot position based on current direction
            const speed = 1.0;
            switch (current_dir) {
                .down => robot_pos.y += speed,
                .down_left => {
                    robot_pos.y += speed * 0.7071; // sin(45°)
                    robot_pos.x -= speed * 0.7071; // cos(45°)
                },
                .left => robot_pos.x -= speed,
                .up_left => {
                    robot_pos.y -= speed * 0.7071; // sin(45°)
                    robot_pos.x -= speed * 0.7071; // cos(45°)
                },
                .up => robot_pos.y -= speed,
                .up_right => {
                    robot_pos.y -= speed * 0.7071; // sin(45°)
                    robot_pos.x += speed * 0.7071; // cos(45°)
                },
                .right => robot_pos.x += speed,
                .down_right => {
                    robot_pos.y += speed * 0.7071; // sin(45°)
                    robot_pos.x += speed * 0.7071; // cos(45°)
                },
            }
        }

        // Draw
        //----------------------------------------------------------------------------------
        rl.beginDrawing();
        defer rl.endDrawing();
        rl.clearBackground(ut.getBackgroundColor());

        // draw map
        tmx.draw(map, tileset_textures);

        // draw robot
        const offset_x = (ut.i32tof32(rl.getRenderWidth()) - ut.i32tof32(robot_static.width)) / 2;
        const offset_y = (ut.i32tof32(rl.getRenderHeight()) - ut.i32tof32(robot_static.height) / num_directions) / 2;
        const draw_pos = rl.Vector2{ .x = robot_pos.x + offset_x, .y = robot_pos.y + offset_y };
        if (!moving) {
            rl.drawTextureRec(robot_static, frame_rec, draw_pos, .white);
        } else {
            rl.drawTextureRec(robot_walk, frame_rec, draw_pos, .white);
        }

        if (comptime builtin.os.tag == .emscripten) {
            if (joy_active) {
                rl.drawCircleV(joy_base, joy_radius, rl.Color.init(128, 128, 128, 80));
                rl.drawCircleLinesV(joy_base, joy_radius, rl.Color.init(200, 200, 200, 150));
                rl.drawCircleV(joy_knob, joy_knob_radius, rl.Color.init(220, 220, 220, 200));
            }
        }
    }
}
