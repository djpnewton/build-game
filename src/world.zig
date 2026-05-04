const gmap = @import("map.zig");
const objects_mod = @import("objects.zig");
const portals = @import("portals.zig");
const robot_mod = @import("robot.zig");
const footsteps_mod = @import("footsteps.zig");

pub const WorldState = struct {
    game_map: gmap.Map = .{},
    obj_map: objects_mod.ObjectMap = .{},
    dungeon: gmap.DungeonMap = .{},
    dungeon_obj_map: objects_mod.ObjectMap = .{},
    in_dungeon: bool = false,
    scene_lock: ?gmap.TilePos = null,

    pub fn init(self: *WorldState) void {
        self.obj_map.scatter(&self.game_map);
    }

    pub fn activeMap(self: *WorldState) *gmap.Map {
        return if (self.in_dungeon) &self.dungeon.map else &self.game_map;
    }

    /// Check and execute dungeon entry / exit transitions each frame.
    pub fn trySceneTransition(
        self: *WorldState,
        tile: gmap.TilePos,
        robot: *robot_mod.Robot,
        footsteps: *footsteps_mod.Footsteps,
    ) void {
        if (self.scene_lock) |lock| {
            if (tile.col != lock.col or tile.row != lock.row) self.scene_lock = null;
        }

        if (self.scene_lock == null) {
            if (!self.in_dungeon) {
                _ = portals.tryTeleport(tile, robot, footsteps, &self.game_map);
                if (tile.col == gmap.overworld_entrance.col and
                    tile.row == gmap.overworld_entrance.row)
                {
                    self.dungeon.ensureGenerated();
                    if (self.dungeon_obj_map.count == 0)
                        self.dungeon_obj_map.place(
                            &self.dungeon.map,
                            gmap.dungeon_spawn.col,
                            gmap.dungeon_spawn.row,
                            .stairs_up,
                        );
                    robot.teleport(gmap.dungeon_spawn);
                    footsteps.clear();
                    footsteps.last_tile = tile;
                    self.dungeon.map.revealAround(gmap.dungeon_spawn.col, gmap.dungeon_spawn.row, 3);
                    self.in_dungeon = true;
                    self.scene_lock = gmap.dungeon_spawn;
                }
            } else {
                if (tile.col == gmap.dungeon_spawn.col and
                    tile.row == gmap.dungeon_spawn.row)
                {
                    robot.teleport(gmap.overworld_entrance);
                    footsteps.clear();
                    footsteps.last_tile = tile;
                    self.in_dungeon = false;
                    self.scene_lock = gmap.overworld_entrance;
                }
            }
        }
    }

    pub fn draw(self: *WorldState, off_x: f32, off_y: f32) void {
        if (self.in_dungeon) {
            self.dungeon.draw(off_x, off_y);
            self.dungeon_obj_map.draw(&self.dungeon.map, off_x, off_y);
        } else {
            self.game_map.draw(off_x, off_y);
            portals.draw(&self.game_map, off_x, off_y);
            self.obj_map.draw(&self.game_map, off_x, off_y);
        }
    }
};
