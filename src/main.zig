const std = @import("std");

const rl = @import("raylib");
const rg = @import("raygui");

const ut = @import("utils.zig");
const gmap = @import("map.zig");
const input = @import("input.zig");

pub fn main(_: std.process.Init) !void {
    // Initialization
    //--------------------------------------------------------------------------------------

    const screenWidth: i32 = @as(i32, @intCast(gmap.COLS)) * gmap.TILE_SIZE;
    const screenHeight: i32 = @as(i32, @intCast(gmap.ROWS)) * gmap.TILE_SIZE;

    rl.setConfigFlags(rl.ConfigFlags{ .window_resizable = true, .msaa_4x_hint = true });
    rl.initWindow(screenWidth, screenHeight, "build-game");
    defer rl.closeWindow(); // Close window and OpenGL context

    // virtual map
    var game_map: gmap.Map = .{};

    // load robot
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

    rl.setTargetFPS(60);
    //--------------------------------------------------------------------------------------

    // Main game loop
    while (!rl.windowShouldClose()) { // Detect window close button or ESC key
        // Update
        //----------------------------------------------------------------------------------

        const inp = input.update();
        // reveal fog around current robot tile
        const tile = gmap.tileFromPos(robot_pos);
        game_map.revealAround(tile.col, tile.row, 3);
        if (inp.down and inp.left) {
            current_dir = dirs.down_left;
        } else if (inp.down and inp.right) {
            current_dir = dirs.down_right;
        } else if (inp.up and inp.left) {
            current_dir = dirs.up_left;
        } else if (inp.up and inp.right) {
            current_dir = dirs.up_right;
        } else if (inp.down) {
            current_dir = dirs.down;
        } else if (inp.up) {
            current_dir = dirs.up;
        } else if (inp.left) {
            current_dir = dirs.left;
        } else if (inp.right) {
            current_dir = dirs.right;
        }
        const moving = inp.down or inp.up or inp.left or inp.right;
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
        game_map.draw();

        // draw robot
        const offset_x = (ut.i32tof32(rl.getRenderWidth()) - ut.i32tof32(robot_static.width)) / 2;
        const offset_y = (ut.i32tof32(rl.getRenderHeight()) - ut.i32tof32(robot_static.height) / num_directions) / 2;
        const draw_pos = rl.Vector2{ .x = robot_pos.x + offset_x, .y = robot_pos.y + offset_y };
        if (!moving) {
            rl.drawTextureRec(robot_static, frame_rec, draw_pos, .white);
        } else {
            rl.drawTextureRec(robot_walk, frame_rec, draw_pos, .white);
        }

        // draw virtual joystick
        input.drawJoystick();
    }
}
