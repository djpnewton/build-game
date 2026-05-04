const gmap = @import("map.zig");
const objects_mod = @import("objects.zig");
const portals = @import("portals.zig");
const robot_mod = @import("robot.zig");
const footsteps_mod = @import("footsteps.zig");

const MAX_DEPTH = 8;

pub const SceneKind = enum { overworld, dungeon };

const OverworldScene = struct {
    tiles: gmap.OverworldMap = .{},
    obj_map: objects_mod.ObjectMap = .{},
};

const DungeonScene = struct {
    tiles: gmap.DungeonMap = .{},
    obj_map: objects_mod.ObjectMap = .{},
};

pub const WorldState = struct {
    overworld: OverworldScene = .{},
    dungeon: DungeonScene = .{},
    scene_stack: [MAX_DEPTH]SceneKind = [_]SceneKind{.overworld} ** MAX_DEPTH,
    scene_depth: usize = 1,
    scene_lock: ?gmap.TilePos = null,

    pub fn init(self: *WorldState) void {
        self.overworld.obj_map.scatter(&self.overworld.tiles.map);
    }

    pub fn currentScene(self: *const WorldState) SceneKind {
        return self.scene_stack[self.scene_depth - 1];
    }

    pub fn activeMap(self: *WorldState) *gmap.TileMap {
        return switch (self.currentScene()) {
            .overworld => &self.overworld.tiles.map,
            .dungeon => &self.dungeon.tiles.map,
        };
    }

    pub fn trySceneTransition(
        self: *WorldState,
        tile: gmap.TilePos,
        robot: *robot_mod.Robot,
        footsteps: *footsteps_mod.Footsteps,
    ) void {
        if (self.scene_lock) |lock| {
            if (tile.col != lock.col or tile.row != lock.row) self.scene_lock = null;
        }
        if (self.scene_lock != null) return;

        switch (self.currentScene()) {
            .overworld => {
                _ = portals.tryTeleport(tile, robot, footsteps, &self.overworld.tiles.map);
                if (tile.col == gmap.overworld_entrance.col and
                    tile.row == gmap.overworld_entrance.row)
                {
                    self.dungeon.tiles.ensureGenerated();
                    if (self.dungeon.obj_map.count == 0)
                        self.dungeon.obj_map.place(
                            &self.dungeon.tiles.map,
                            gmap.dungeon_spawn.col,
                            gmap.dungeon_spawn.row,
                            .stairs_up,
                        );
                    robot.teleport(gmap.dungeon_spawn);
                    footsteps.clear();
                    footsteps.last_tile = tile;
                    self.dungeon.tiles.map.revealAround(gmap.dungeon_spawn.col, gmap.dungeon_spawn.row, 3);
                    self.scene_stack[self.scene_depth] = .dungeon;
                    self.scene_depth += 1;
                    self.scene_lock = gmap.dungeon_spawn;
                }
            },
            .dungeon => {
                if (tile.col == gmap.dungeon_spawn.col and
                    tile.row == gmap.dungeon_spawn.row)
                {
                    robot.teleport(gmap.overworld_entrance);
                    footsteps.clear();
                    footsteps.last_tile = tile;
                    self.scene_depth -= 1;
                    self.scene_lock = gmap.overworld_entrance;
                }
            },
        }
    }

    pub fn draw(self: *WorldState, off_x: f32, off_y: f32) void {
        switch (self.currentScene()) {
            .overworld => {
                self.overworld.tiles.draw(off_x, off_y);
                portals.draw(&self.overworld.tiles.map, off_x, off_y);
                self.overworld.obj_map.draw(&self.overworld.tiles.map, off_x, off_y);
            },
            .dungeon => {
                self.dungeon.tiles.draw(off_x, off_y);
                self.dungeon.obj_map.draw(&self.dungeon.tiles.map, off_x, off_y);
            },
        }
    }
};
