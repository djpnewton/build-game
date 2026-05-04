const rl = @import("raylib");

pub const joy_radius: f32 = 60;
pub const joy_knob_radius: f32 = 25;
const joy_threshold: f32 = 0.3;
// A touch that travels less than this before lifting counts as a tap
const tap_max_travel: f32 = joy_radius * 0.5;

var joy_active: bool = false;
var joy_touch_id: i32 = -1;
var joy_base: rl.Vector2 = .{ .x = 0, .y = 0 };
var joy_knob: rl.Vector2 = .{ .x = 0, .y = 0 };
var joy_dx: f32 = 0;
var joy_dy: f32 = 0;
var joy_max_travel: f32 = 0;

var pending_tap: ?rl.Vector2 = null;

pub const State = struct {
    up: bool,
    down: bool,
    left: bool,
    right: bool,
};

/// Call every frame. Updates joystick tracking and detects taps.
pub fn pollAll() void {
    // Mouse tap (desktop)
    if (rl.getTouchPointCount() == 0 and rl.isMouseButtonPressed(.left)) {
        pending_tap = rl.getMousePosition();
    }

    // Touch tracking
    const touch_count = rl.getTouchPointCount();
    if (!joy_active and touch_count > 0) {
        for (0..@intCast(touch_count)) |i| {
            const idx: i32 = @intCast(i);
            const tp = rl.getTouchPosition(idx);
            joy_active = true;
            joy_touch_id = rl.getTouchPointId(idx);
            joy_base = tp;
            joy_knob = tp;
            joy_max_travel = 0;
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
                    if (dist > joy_max_travel) joy_max_travel = dist;
                    joy_dx = (joy_knob.x - joy_base.x) / joy_radius;
                    joy_dy = (joy_knob.y - joy_base.y) / joy_radius;
                    found = true;
                    break;
                }
            }
        }
        if (!found) {
            // Touch lifted: small travel = tap
            if (joy_max_travel < tap_max_travel) {
                pending_tap = joy_base;
            }
            joy_active = false;
            joy_dx = 0;
            joy_dy = 0;
        }
    }
}

/// Returns and clears the pending tap position (mouse click or touch tap).
pub fn consumeTap() ?rl.Vector2 {
    const t = pending_tap;
    pending_tap = null;
    return t;
}

/// Call per-tile to read current directional input (keyboard + joystick).
pub fn update() State {
    return .{
        .up = rl.isKeyDown(.up) or joy_dy < -joy_threshold,
        .down = rl.isKeyDown(.down) or joy_dy > joy_threshold,
        .left = rl.isKeyDown(.left) or joy_dx < -joy_threshold,
        .right = rl.isKeyDown(.right) or joy_dx > joy_threshold,
    };
}

pub fn drawJoystick() void {
    if (joy_active and joy_max_travel >= tap_max_travel) {
        rl.drawCircleV(joy_base, joy_radius, rl.Color.init(128, 128, 128, 80));
        rl.drawCircleLinesV(joy_base, joy_radius, rl.Color.init(200, 200, 200, 150));
        rl.drawCircleV(joy_knob, joy_knob_radius, rl.Color.init(220, 220, 220, 200));
    }
}
