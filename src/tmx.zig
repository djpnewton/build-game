const std = @import("std");

const xml = @import("xml");
const rl = @import("raylib");

pub const Tileset = struct {
    first_gid: u32,
    name: []u8,
    tile_width: u32,
    tile_height: u32,
    columns: u32,
    image_source: []u8,
    image_width: u32,
    image_height: u32,

    pub fn deinit(self: *Tileset, gpa: std.mem.Allocator) void {
        gpa.free(self.name);
        gpa.free(self.image_source);
    }
};

pub const Layer = struct {
    name: []u8,
    width: u32,
    height: u32,
    /// Tile GIDs in row-major order. 0 means empty.
    tiles: []u32,

    pub fn deinit(self: *Layer, gpa: std.mem.Allocator) void {
        gpa.free(self.name);
        gpa.free(self.tiles);
    }

    pub fn gidAt(self: Layer, col: u32, row: u32) u32 {
        return self.tiles[row * self.width + col];
    }
};

pub const Map = struct {
    width: u32,
    height: u32,
    tile_width: u32,
    tile_height: u32,
    tilesets: []Tileset,
    layers: []Layer,

    pub fn deinit(self: *Map, gpa: std.mem.Allocator) void {
        for (self.tilesets) |*ts| ts.deinit(gpa);
        gpa.free(self.tilesets);
        for (self.layers) |*l| l.deinit(gpa);
        gpa.free(self.layers);
    }

    /// Returns the tileset that owns the given GID (or null for GID 0 / empty).
    pub fn tilesetForGid(self: Map, gid: u32) ?*const Tileset {
        if (gid == 0) return null;
        var best: ?*const Tileset = null;
        for (self.tilesets) |*ts| {
            if (ts.first_gid <= gid) {
                if (best == null or ts.first_gid > best.?.first_gid) {
                    best = ts;
                }
            }
        }
        return best;
    }
};

fn attr(reader: *xml.Reader, name: []const u8) ?[]const u8 {
    const count = reader.attributeCount();
    for (0..count) |i| {
        if (std.mem.eql(u8, reader.attributeName(i), name)) {
            return reader.attributeValueRaw(i);
        }
    }
    return null;
}

fn parseU32(s: []const u8) u32 {
    return std.fmt.parseInt(u32, s, 10) catch 0;
}

fn parseCsvTiles(gpa: std.mem.Allocator, text: []const u8) ![]u32 {
    var list: std.ArrayList(u32) = .empty;
    errdefer list.deinit(gpa);
    var it = std.mem.tokenizeAny(u8, text, " ,\t\r\n");
    while (it.next()) |token| {
        try list.append(gpa, std.fmt.parseInt(u32, token, 10) catch 0);
    }
    return list.toOwnedSlice(gpa);
}

pub fn load(gpa: std.mem.Allocator, tmx_data: []const u8) !Map {
    var static_reader: xml.Reader.Static = .init(gpa, tmx_data, .{ .namespace_aware = false });
    defer static_reader.deinit();
    const reader = &static_reader.interface;

    var map: Map = .{
        .width = 0,
        .height = 0,
        .tile_width = 0,
        .tile_height = 0,
        .tilesets = &.{},
        .layers = &.{},
    };

    var tilesets: std.ArrayList(Tileset) = .empty;
    errdefer {
        for (tilesets.items) |*ts| ts.deinit(gpa);
        tilesets.deinit(gpa);
    }
    var layers: std.ArrayList(Layer) = .empty;
    errdefer {
        for (layers.items) |*l| l.deinit(gpa);
        layers.deinit(gpa);
    }

    var in_layer = false;
    var in_data = false;
    var current_layer: Layer = .{ .name = &.{}, .width = 0, .height = 0, .tiles = &.{} };
    var current_tileset: Tileset = .{
        .first_gid = 0,
        .name = &.{},
        .tile_width = 0,
        .tile_height = 0,
        .columns = 0,
        .image_source = &.{},
        .image_width = 0,
        .image_height = 0,
    };
    var in_tileset = false;

    while (true) {
        const node = try reader.read();
        switch (node) {
            .eof => break,
            .element_start => {
                const elem = reader.elementName();
                if (std.mem.eql(u8, elem, "map")) {
                    map.width = parseU32(attr(reader, "width") orelse "0");
                    map.height = parseU32(attr(reader, "height") orelse "0");
                    map.tile_width = parseU32(attr(reader, "tilewidth") orelse "0");
                    map.tile_height = parseU32(attr(reader, "tileheight") orelse "0");
                } else if (std.mem.eql(u8, elem, "tileset")) {
                    current_tileset = .{
                        .first_gid = parseU32(attr(reader, "firstgid") orelse "1"),
                        .name = try gpa.dupe(u8, attr(reader, "name") orelse ""),
                        .tile_width = parseU32(attr(reader, "tilewidth") orelse "0"),
                        .tile_height = parseU32(attr(reader, "tileheight") orelse "0"),
                        .columns = parseU32(attr(reader, "columns") orelse "0"),
                        .image_source = &.{},
                        .image_width = 0,
                        .image_height = 0,
                    };
                    in_tileset = true;
                } else if (std.mem.eql(u8, elem, "image") and in_tileset) {
                    if (current_tileset.image_source.len == 0) {
                        current_tileset.image_source = try gpa.dupe(u8, attr(reader, "source") orelse "");
                    }
                    current_tileset.image_width = parseU32(attr(reader, "width") orelse "0");
                    current_tileset.image_height = parseU32(attr(reader, "height") orelse "0");
                } else if (std.mem.eql(u8, elem, "layer")) {
                    current_layer = .{
                        .name = try gpa.dupe(u8, attr(reader, "name") orelse ""),
                        .width = parseU32(attr(reader, "width") orelse "0"),
                        .height = parseU32(attr(reader, "height") orelse "0"),
                        .tiles = &.{},
                    };
                    in_layer = true;
                } else if (std.mem.eql(u8, elem, "data") and in_layer) {
                    in_data = true;
                }
            },
            .text => {
                if (in_data and current_layer.tiles.len == 0) {
                    current_layer.tiles = try parseCsvTiles(gpa, reader.textRaw());
                }
            },
            .element_end => {
                const elem = reader.elementName();
                if (std.mem.eql(u8, elem, "tileset") and in_tileset) {
                    try tilesets.append(gpa, current_tileset);
                    current_tileset = .{
                        .first_gid = 0,
                        .name = &.{},
                        .tile_width = 0,
                        .tile_height = 0,
                        .columns = 0,
                        .image_source = &.{},
                        .image_width = 0,
                        .image_height = 0,
                    };
                    in_tileset = false;
                } else if (std.mem.eql(u8, elem, "data")) {
                    in_data = false;
                } else if (std.mem.eql(u8, elem, "layer") and in_layer) {
                    try layers.append(gpa, current_layer);
                    current_layer = .{ .name = &.{}, .width = 0, .height = 0, .tiles = &.{} };
                    in_layer = false;
                }
            },
            else => {},
        }
    }

    map.tilesets = try tilesets.toOwnedSlice(gpa);
    map.layers = try layers.toOwnedSlice(gpa);
    return map;
}

// Use C stdio instead of std.Io: Emscripten intercepts fopen/fread correctly,
// but std.Io.Dir.readFileAlloc uses pread with a 64-bit offset that triggers an
// assertion failure in Emscripten's FS (convertI32PairToI53Checked overflow).
const libc_file = struct {
    const FILE = anyopaque;
    extern fn fopen(path: [*:0]const u8, mode: [*:0]const u8) ?*FILE;
    extern fn fclose(f: *FILE) c_int;
    extern fn fseek(f: *FILE, offset: c_long, whence: c_int) c_int;
    extern fn ftell(f: *FILE) c_long;
    extern fn fread(ptr: *anyopaque, size: usize, nmemb: usize, f: *FILE) usize;
};

pub fn loadFile(gpa: std.mem.Allocator, path: []const u8) !Map {
    const path_z = try gpa.dupeZ(u8, path);
    defer gpa.free(path_z);
    const f = libc_file.fopen(path_z, "rb") orelse return error.FileNotFound;
    defer _ = libc_file.fclose(f);
    _ = libc_file.fseek(f, 0, 2); // SEEK_END
    const size = libc_file.ftell(f);
    if (size <= 0) return error.InvalidFile;
    _ = libc_file.fseek(f, 0, 0); // SEEK_SET
    const buf = try gpa.alloc(u8, @intCast(size));
    defer gpa.free(buf);
    const n = libc_file.fread(buf.ptr, 1, @intCast(size), f);
    if (n != @as(usize, @intCast(size))) return error.ReadFailed;
    return load(gpa, buf);
}

pub fn loadTextures(gpa: std.mem.Allocator, map: Map, tmx_dir: []const u8) ![]rl.Texture {
    var textures: std.ArrayList(rl.Texture) = .empty;
    errdefer {
        for (textures.items) |t| rl.unloadTexture(t);
        textures.deinit(gpa);
    }
    for (map.tilesets) |ts| {
        const full_path = try std.fs.path.join(gpa, &.{ tmx_dir, ts.image_source });
        defer gpa.free(full_path);
        const path_z = try gpa.dupeZ(u8, full_path);
        defer gpa.free(path_z);
        const tex = rl.loadTexture(path_z) catch {
            return error.LoadTextureFailed;
        };
        try textures.append(gpa, tex);
    }
    return textures.toOwnedSlice(gpa);
}

pub fn draw(map: Map, tileset_textures: []rl.Texture) void {
    const offset_x: f32 = (@as(f32, @floatFromInt(rl.getRenderWidth())) - @as(f32, @floatFromInt(map.width * map.tile_width))) / 2;
    const offset_y: f32 = (@as(f32, @floatFromInt(rl.getRenderHeight())) - @as(f32, @floatFromInt(map.height * map.tile_height))) / 2;
    for (map.layers) |layer| {
        for (layer.tiles, 0..layer.tiles.len) |gid, i| {
            if (gid == 0) continue;
            const ts = map.tilesetForGid(gid) orelse continue;
            const local_id = gid - ts.first_gid;
            const ts_idx: usize = @divExact(@intFromPtr(ts) - @intFromPtr(map.tilesets.ptr), @sizeOf(Tileset));
            const ii: u32 = @intCast(i);
            const src_x: f32 = @floatFromInt((local_id % ts.columns) * ts.tile_width);
            const src_y: f32 = @floatFromInt((local_id / ts.columns) * ts.tile_height);
            const dst_x: f32 = @as(f32, @floatFromInt((ii % layer.width) * map.tile_width)) + offset_x;
            const dst_y: f32 = @as(f32, @floatFromInt((ii / layer.width) * map.tile_height)) + offset_y;
            rl.drawTextureRec(tileset_textures[ts_idx], .{ .x = src_x, .y = src_y, .width = @floatFromInt(ts.tile_width), .height = @floatFromInt(ts.tile_height) }, .{ .x = dst_x, .y = dst_y }, .white);
        }
    }
}
