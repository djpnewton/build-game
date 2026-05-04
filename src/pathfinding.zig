const std = @import("std");

const gmap = @import("map.zig");

const N = gmap.COLS * gmap.ROWS;

/// A* on the 20×20 tile grid, 8-directional movement.
/// Writes the path (excluding start, including goal) into `out`.
/// Returns the number of tiles written, or 0 if no path exists.
pub fn findPath(
    map: *const gmap.Map,
    start: gmap.TilePos,
    goal: gmap.TilePos,
    out: []gmap.TilePos,
) usize {
    if (start.col == goal.col and start.row == goal.row) return 0;
    if (goal.col < 0 or goal.col >= gmap.COLS or goal.row < 0 or goal.row >= gmap.ROWS) return 0;
    if (map.isBlocked(goal.col, goal.row)) return 0;

    var g: [N]f32 = undefined;
    var parent: [N]i16 = undefined;
    var in_open: [N]bool = undefined;
    var closed: [N]bool = undefined;
    for (0..N) |i| {
        g[i] = 1e30;
        parent[i] = -1;
        in_open[i] = false;
        closed[i] = false;
    }

    const si = index(start.col, start.row);
    g[si] = 0;
    in_open[si] = true;

    while (true) {
        // Linear scan for the open node with lowest f = g + octile-heuristic
        var best_i: i32 = -1;
        var best_f: f32 = 1e30;
        for (0..N) |i| {
            if (!in_open[i]) continue;
            const c: f32 = @floatFromInt(i % gmap.COLS);
            const r: f32 = @floatFromInt(i / gmap.COLS);
            const dc = @abs(c - @as(f32, @floatFromInt(goal.col)));
            const dr = @abs(r - @as(f32, @floatFromInt(goal.row)));
            const h = @max(dc, dr) + (1.4142136 - 1.0) * @min(dc, dr);
            const f = g[i] + h;
            if (f < best_f) {
                best_f = f;
                best_i = @intCast(i);
            }
        }
        if (best_i < 0) return 0; // no path

        const bi: usize = @intCast(best_i);
        in_open[bi] = false;
        closed[bi] = true;

        const bc: i32 = @intCast(bi % gmap.COLS);
        const br: i32 = @intCast(bi / gmap.COLS);

        if (bc == goal.col and br == goal.row) {
            // Count path length
            var len: usize = 0;
            var cur: i16 = @intCast(bi);
            while (@as(usize, @intCast(cur)) != si) {
                len += 1;
                cur = parent[@intCast(cur)];
            }
            if (len == 0 or len > out.len) return 0;
            // Write path in forward order
            cur = @intCast(bi);
            var wi: usize = len;
            while (@as(usize, @intCast(cur)) != si) {
                wi -= 1;
                const ci: usize = @intCast(cur);
                out[wi] = .{ .col = @intCast(ci % gmap.COLS), .row = @intCast(ci / gmap.COLS) };
                cur = parent[ci];
            }
            return len;
        }

        // Expand 8 neighbours
        var dr_: i32 = -1;
        while (dr_ <= 1) : (dr_ += 1) {
            var dc_: i32 = -1;
            while (dc_ <= 1) : (dc_ += 1) {
                if (dc_ == 0 and dr_ == 0) continue;
                const nc = bc + dc_;
                const nr = br + dr_;
                if (nc < 0 or nc >= gmap.COLS or nr < 0 or nr >= gmap.ROWS) continue;
                if (map.isBlocked(nc, nr)) continue;
                const ni = index(nc, nr);
                if (closed[ni]) continue;
                const step: f32 = if (dc_ != 0 and dr_ != 0) 1.4142136 else 1.0;
                const ng = g[bi] + step;
                if (ng < g[ni]) {
                    g[ni] = ng;
                    parent[ni] = @intCast(bi);
                    in_open[ni] = true;
                }
            }
        }
    }
}

/// Like findPath, but if `goal` is blocked (or out of bounds) it searches
/// outward from `goal` in BFS order to find the nearest walkable tile.
pub fn findPathTo(
    map: *const gmap.Map,
    start: gmap.TilePos,
    goal: gmap.TilePos,
    out: []gmap.TilePos,
) usize {
    // If goal is valid and walkable, go straight to it.
    if (goal.col >= 0 and goal.col < gmap.COLS and
        goal.row >= 0 and goal.row < gmap.ROWS and
        !map.isBlocked(goal.col, goal.row))
    {
        return findPath(map, start, goal, out);
    }

    // BFS outward from goal to find nearest walkable tile.
    var visited: [N]bool = [_]bool{false} ** N;
    var queue: [N]gmap.TilePos = undefined;
    var head: usize = 0;
    var tail: usize = 0;

    // Seed the queue with all in-bounds cells in a small ring around goal.
    // We initialise with the goal itself (possibly OOB) then expand.
    const clamped: gmap.TilePos = .{
        .col = std.math.clamp(goal.col, 0, @as(i32, @intCast(gmap.COLS)) - 1),
        .row = std.math.clamp(goal.row, 0, @as(i32, @intCast(gmap.ROWS)) - 1),
    };
    const si = index(clamped.col, clamped.row);
    visited[si] = true;
    queue[tail] = clamped;
    tail += 1;

    while (head < tail) {
        const cur = queue[head];
        head += 1;
        if (!map.isBlocked(cur.col, cur.row)) {
            return findPath(map, start, cur, out);
        }
        // Expand 4-connected neighbours (cardinal only for nearest tile).
        const dirs = [4][2]i32{ .{ 0, -1 }, .{ 0, 1 }, .{ -1, 0 }, .{ 1, 0 } };
        for (dirs) |d| {
            const nc = cur.col + d[0];
            const nr = cur.row + d[1];
            if (nc < 0 or nc >= gmap.COLS or nr < 0 or nr >= gmap.ROWS) continue;
            const ni = index(nc, nr);
            if (visited[ni]) continue;
            visited[ni] = true;
            queue[tail] = .{ .col = nc, .row = nr };
            tail += 1;
        }
    }
    return 0; // entire map is blocked
}

inline fn index(col: i32, row: i32) usize {
    return @as(usize, @intCast(row)) * gmap.COLS + @as(usize, @intCast(col));
}
