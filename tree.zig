const std = @import("std");
const ray = @cImport({
    @cInclude("raylib.h");
});

const WINDOW_WIDTH: i32 = 800;
const WINDOW_HEIGHT: i32 = 600;
const MAX_DEPTH: usize = 6;
const LEAF_SIZE: f32 = 0.5;

const Vec3 = ray.Vector3;

fn vec3Add(a: Vec3, b: Vec3) Vec3 {
    return Vec3{ .x = a.x + b.x, .y = a.y + b.y, .z = a.z + b.z };
}

fn vec3Scale(v: Vec3, scale: f32) Vec3 {
    return Vec3{ .x = v.x * scale, .y = v.y * scale, .z = v.z * scale };
}

fn vec3Normalize(v: Vec3) Vec3 {
    const length = @sqrt(v.x * v.x + v.y * v.y + v.z * v.z);
    if (length == 0) return v;
    return Vec3{ .x = v.x / length, .y = v.y / length, .z = v.z / length };
}

fn vec3CrossProduct(a: Vec3, b: Vec3) Vec3 {
    return Vec3{
        .x = a.y * b.z - a.z * b.y,
        .y = a.z * b.x - a.x * b.z,
        .z = a.x * b.y - a.y * b.x,
    };
}

const BranchProperties = struct {
    length_range: [2]f32,
    width: f32,
    angle_range: [2]f32,
    branching_range: [2]u32,

    fn init(length_range: [2]f32, width: f32, angle_range: [2]f32, branching_range: [2]u32) BranchProperties {
        return .{
            .length_range = length_range,
            .width = width,
            .angle_range = angle_range,
            .branching_range = branching_range,
        };
    }
};

const Branch = struct {
    start: Vec3,
    end: Vec3,
    width: f32,
};

fn randomGreenShade() ray.Color {
    return ray.Color{
        .r = std.crypto.random.int(u8) % 50,
        .g = std.crypto.random.int(u8) % 156 + 100,
        .b = std.crypto.random.int(u8) % 100,
        .a = 255,
    };
}

const Tree = struct {
    branches: std.ArrayList(Branch),
    leaf_positions: std.ArrayList(Vec3),
    leaf_colors: std.ArrayList(ray.Color),

    fn init(allocator: std.mem.Allocator) Tree {
        return .{
            .branches = std.ArrayList(Branch).init(allocator),
            .leaf_positions = std.ArrayList(Vec3).init(allocator),
            .leaf_colors = std.ArrayList(ray.Color).init(allocator),
        };
    }

    fn deinit(self: *Tree) void {
        self.branches.deinit();
        self.leaf_positions.deinit();
        self.leaf_colors.deinit();
    }
};

fn randomFloat(min: f32, max: f32) f32 {
    return min + (max - min) * std.crypto.random.float(f32);
}

fn updateBranchProperties(props: BranchProperties, depth: usize, angle_ranges: []const [2]f32, length_ranges: []const [2]f32, branching_ranges: []const [2]u32) BranchProperties {
    const current_depth = @min(depth, angle_ranges.len - 1);
    const current_angle_range = angle_ranges[current_depth];
    const current_length_range = length_ranges[current_depth];
    const current_branching_range = branching_ranges[current_depth];

    return BranchProperties.init(current_length_range, props.width * 0.8, current_angle_range, current_branching_range);
}

fn generateBranch(tree: *Tree, start: Vec3, direction: Vec3, props: BranchProperties, depth: usize, max_depth: usize, angle_ranges: []const [2]f32, length_ranges: []const [2]f32, branching_ranges: []const [2]u32) !void {
    if (depth == max_depth) {
        try tree.leaf_positions.append(start);
        try tree.leaf_colors.append(randomGreenShade());
        return;
    }

    const length = randomFloat(props.length_range[0], props.length_range[1]);
    const end = vec3Add(start, vec3Scale(direction, length));
    try tree.branches.append(.{ .start = start, .end = end, .width = props.width });

    if (depth < max_depth - 1) {
        const num_branches = std.crypto.random.intRangeAtMost(u32, props.branching_range[0], props.branching_range[1]);
        var i: u32 = 0;
        while (i < num_branches) : (i += 1) {
            const rotation_axis = vec3Normalize(vec3CrossProduct(direction, Vec3{ .x = randomFloat(-1, 1), .y = randomFloat(-1, 1), .z = randomFloat(-1, 1) }));
            const angle = randomFloat(props.angle_range[0], props.angle_range[1]);
            const rotation_matrix = rotationMatrixFromAxisAngle(rotation_axis, angle);

            var new_direction = transformVector(direction, rotation_matrix);
            new_direction = vec3Normalize(new_direction);

            const new_props = updateBranchProperties(props, depth + 1, angle_ranges, length_ranges, branching_ranges);

            try generateBranch(tree, end, new_direction, new_props, depth + 1, max_depth, angle_ranges, length_ranges, branching_ranges);
        }
    } else {
        const num_leaves = 5;
        var j: u32 = 0;
        while (j < num_leaves) : (j += 1) {
            const leaf_offset = Vec3{
                .x = randomFloat(-0.5, 0.5),
                .y = randomFloat(-0.5, 0.5),
                .z = randomFloat(-0.5, 0.5),
            };
            try tree.leaf_positions.append(vec3Add(end, leaf_offset));
            try tree.leaf_colors.append(randomGreenShade());
        }
    }
}

fn rotationMatrixFromAxisAngle(axis: Vec3, angle: f32) ray.Matrix {
    const x = axis.x;
    const y = axis.y;
    const z = axis.z;
    const c = @cos(angle);
    const s = @sin(angle);
    const t = 1.0 - c;

    return ray.Matrix{
        .m0 = t * x * x + c,
        .m4 = t * x * y - s * z,
        .m8 = t * x * z + s * y,
        .m12 = 0.0,
        .m1 = t * x * y + s * z,
        .m5 = t * y * y + c,
        .m9 = t * y * z - s * x,
        .m13 = 0.0,
        .m2 = t * x * z - s * y,
        .m6 = t * y * z + s * x,
        .m10 = t * z * z + c,
        .m14 = 0.0,
        .m3 = 0.0,
        .m7 = 0.0,
        .m11 = 0.0,
        .m15 = 1.0,
    };
}

fn transformVector(v: Vec3, m: ray.Matrix) Vec3 {
    return Vec3{
        .x = v.x * m.m0 + v.y * m.m4 + v.z * m.m8 + m.m12,
        .y = v.x * m.m1 + v.y * m.m5 + v.z * m.m9 + m.m13,
        .z = v.x * m.m2 + v.y * m.m6 + v.z * m.m10 + m.m14,
    };
}

fn createTree(allocator: std.mem.Allocator, trunk_props: BranchProperties, max_depth: usize, angle_ranges: []const [2]f32, length_ranges: []const [2]f32, branching_ranges: []const [2]u32) !Tree {
    var tree = Tree.init(allocator);
    const start = Vec3{ .x = 0, .y = 0, .z = 0 };
    const direction = Vec3{ .x = 0, .y = 1, .z = 0 };
    try generateBranch(&tree, start, direction, trunk_props, 0, max_depth, angle_ranges, length_ranges, branching_ranges);
    return tree;
}

const Camera = struct {
    camera: ray.Camera3D,
    target: ray.Vector3,
    angle: f32,
    pitch: f32,
    distance: f32,

    fn init() Camera {
        return .{
            .camera = ray.Camera3D{
                .position = .{ .x = 10, .y = 10, .z = 10 },
                .target = .{ .x = 0, .y = 5, .z = 0 },
                .up = .{ .x = 0, .y = 1, .z = 0 },
                .fovy = 45.0,
                .projection = ray.CAMERA_PERSPECTIVE,
            },
            .target = .{ .x = 0, .y = 5, .z = 0 },
            .angle = 0,
            .pitch = std.math.pi / 6.0,
            .distance = 15,
        };
    }

    fn update(self: *Camera) void {
        if (ray.IsMouseButtonDown(ray.MOUSE_BUTTON_LEFT)) {
            const delta = ray.GetMouseDelta();
            self.angle -= delta.x * 0.01;
            self.pitch -= delta.y * 0.01;
        }

        const wheel = ray.GetMouseWheelMove();
        if (wheel != 0) {
            self.distance -= wheel * 0.5;
            self.distance = std.math.clamp(self.distance, 5, 30);
        }

        self.camera.position = .{
            .x = self.target.x + self.distance * @cos(self.pitch) * @cos(self.angle),
            .y = self.target.y + self.distance * @sin(self.pitch),
            .z = self.target.z + self.distance * @cos(self.pitch) * @sin(self.angle),
        };

        self.camera.target = self.target;
    }
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    ray.InitWindow(WINDOW_WIDTH, WINDOW_HEIGHT, "3D Tree Generation");
    defer ray.CloseWindow();

    const trunk_props = BranchProperties.init(.{ 2.0, 3.0 }, 0.4, .{ @as(f32, -std.math.pi) / 6.0, @as(f32, std.math.pi) / 6.0 }, .{ 3, 5 });

    const angle_ranges = [_][2]f32{
        .{ @as(f32, -std.math.pi) / 4.0, @as(f32, std.math.pi) / 4.0 },
        .{ @as(f32, -std.math.pi) / 3.0, @as(f32, std.math.pi) / 3.0 },
        .{ @as(f32, -std.math.pi) / 2.0, @as(f32, std.math.pi) / 2.0 },
        .{ @as(f32, -std.math.pi) / 2.0, @as(f32, std.math.pi) / 2.0 },
        .{ @as(f32, -std.math.pi) / 2.0, @as(f32, std.math.pi) / 2.0 },
        .{ @as(f32, -std.math.pi) / 2.0, @as(f32, std.math.pi) / 2.0 },
    };

    const length_ranges = [_][2]f32{
        .{ 1.5, 2.0 },
        .{ 1.2, 1.6 },
        .{ 0.8, 1.2 },
        .{ 0.5, 0.8 },
        .{ 0.3, 0.5 },
        .{ 0.2, 0.3 },
    };

    const branching_ranges = [_][2]u32{
        .{ 3, 5 },
        .{ 2, 4 },
        .{ 2, 3 },
        .{ 1, 3 },
        .{ 1, 2 },
        .{ 0, 2 },
    };

    var tree = try createTree(allocator, trunk_props, MAX_DEPTH, &angle_ranges, &length_ranges, &branching_ranges);
    defer tree.deinit();

    var camera = Camera.init();

    ray.SetTargetFPS(60);

    while (!ray.WindowShouldClose()) {
        camera.update();

        if (ray.IsMouseButtonPressed(ray.MOUSE_BUTTON_RIGHT)) {
            tree.deinit();
            tree = try createTree(allocator, trunk_props, MAX_DEPTH, &angle_ranges, &length_ranges, &branching_ranges);
        }

        ray.BeginDrawing();
        ray.ClearBackground(ray.RAYWHITE);

        ray.BeginMode3D(camera.camera);

        for (tree.branches.items) |branch| {
            ray.DrawCylinderEx(branch.start, branch.end, branch.width, branch.width * 0.8, 8, ray.BROWN);
        }

        for (tree.leaf_positions.items, tree.leaf_colors.items) |leaf_pos, leaf_color| {
            ray.DrawSphere(leaf_pos, LEAF_SIZE, leaf_color);
        }

        ray.DrawGrid(10, 1.0);

        ray.EndMode3D();

        ray.DrawFPS(10, 10);

        ray.EndDrawing();
    }
}
