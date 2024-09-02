const std = @import("std");
const gl = @import("zopengl").bindings;
const glfw = @import("zglfw");
const gui = @import("zgui");
const math = @import("zmath");
// const arg = @import("args.zig");
const Chunk = @import("chunk/Chunk.zig").Chunk;
const ChunkMeshBufferPool = @import("chunk/chunkBuffer.zig").ChunkMeshBufferPool;
const chunk_mesher = @import("chunk/chunkMesher.zig");
const shaders = @import("gl/ShaderProgram.zig");
const State = @import("State.zig").State;
const Camera = @import("Camera.zig").Camera;

/// Main entrypoint.
pub fn main() !void {
    // try arg.GetCLArguments();

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const gpa_alloc = gpa.allocator();

    var state = try State.create(gpa_alloc);
    defer state.destroy();

    var shader_program = try shaders.ShaderProgram.create(gpa_alloc);
    defer shader_program.destroy();

    try shader_program.attach(.{
        .AsSource = .{
            .source =
            \\#version 460 core
            \\layout (location=0) in vec3 i_vert_position;
            \\layout (location=1) in uint i_inst_data;
            \\layout (location=2) in uint i_draw_id;
            \\layout (location=0) out vec3 o_vert_colour;
            \\layout (location=0) uniform mat4 u_model_view_project;
            \\void main(){
            \\vec4 inst_position = vec4(float(i_inst_data & 31), float((i_inst_data >> 5) & 31), float((i_inst_data >> 10) & 31), 1.0);
            \\vec2 inst_size = vec2(float((i_inst_data >> 15) & 31), float((i_inst_data >> 20) & 31));
            \\vec4 vert_position = vec4(i_vert_position, 0.0);
            \\switch (gl_DrawID) {
            \\case 0:
            \\case 1: vert_position.zy *= inst_size; break;
            \\case 2:
            \\case 3: vert_position.zx *= inst_size; break;
            \\case 4:
            \\case 5: vert_position.xy *= inst_size; break;
            \\}
            \\gl_Position = u_model_view_project * (inst_position + vert_position);
            \\o_vert_colour = vec3(0.0, float(gl_DrawID) / 3.0, 0.0);
            \\}
            ,
            .target = shaders.ShaderStageTarget.Vertex,
        },
    });
    try shader_program.attach(.{
        .AsSource = .{
            .source =
            \\#version 430 core
            \\layout (location=0) in vec3 i_colour;
            \\layout (location=0) out vec4 o_colour;
            \\void main() {
            \\o_colour = vec4(i_colour, 0.1);
            \\}
            ,
            .target = shaders.ShaderStageTarget.Fragment,
        },
    });
    try shader_program.link();

    var camera = Camera.create([_]f32{ 0.5, 0.5, -5.0 }, [_]f32{ 0.0, 0.0, 0.0 });

    try ChunkMeshBufferPool.setUp(gpa_alloc);
    defer ChunkMeshBufferPool.tearDown();
    ChunkMeshBufferPool.addChunkInstances();

    // try ChunkMeshBufferPool.readBlockModelsJson();

    var last_interval: f64 = 0.0;
    var cycle_pressed: bool = false;
    var wireframe_enabled: bool = false;
    var wireframe_pressed: bool = false;

    while (!state.window.shouldClose()) {
        const this_interval = glfw.getTime();
        const timestep = this_interval - last_interval;

        glfw.pollEvents();

        if (state.window.getKey(.escape) == .press) {
            state.window.setShouldClose(true);
        }

        if (state.window.getKey(.g) == .press) {
            if (!cycle_pressed) {
                camera.cycleMovementTypes();
                cycle_pressed = true;
            }
        } else {
            cycle_pressed = false;
        }

        if (state.window.getKey(.h) == .press) {
            if (!wireframe_pressed) {
                if (wireframe_enabled) {
                    gl.polygonMode(gl.FRONT_AND_BACK, gl.FILL);
                } else {
                    gl.polygonMode(gl.FRONT_AND_BACK, gl.LINE);
                }

                wireframe_enabled = !wireframe_enabled;
                wireframe_pressed = true;
            }
        } else {
            wireframe_pressed = false;
        }

        camera.doInput(state, timestep);

        const mvp = camera.getMvpMatrix(state);

        try shader_program.setUniformMatrix("u_model_view_project", 4, 4, 1, true, f32, math.arrNPtr(&mvp));

        gl.clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);

        shader_program.use();

        ChunkMeshBufferPool.draw();

        const fb_size = state.window.getFramebufferSize();

        gui.backend.newFrame(@intCast(fb_size[0]), @intCast(fb_size[1]));

        if (gui.begin("Test window", .{})) {
            gui.bulletText("Hello world!", .{});

            if (gui.beginTable("Camera", .{
                .column = 1,
                .flags = .{
                    .resizable = false,
                },
                .outer_size = .{ 360.0, 240.0 },
                .inner_width = 256,
            })) {
                gui.tableNextRow(.{
                    .min_row_height = 32,
                    .row_flags = .{
                        .headers = true,
                        ._padding = 0,
                    },
                });

                if (gui.tableNextColumn()) {
                    gui.text("Camera:", .{});
                }

                gui.tableNextRow(.{
                    .min_row_height = 32,
                    .row_flags = .{
                        .headers = false,
                        ._padding = 0,
                    },
                });

                if (gui.tableNextColumn()) {
                    gui.text("Position: {d}, {d}, {d}", .{ camera.position[0], camera.position[1], camera.position[2] });
                }

                gui.tableNextRow(.{
                    .min_row_height = 32,
                    .row_flags = .{
                        .headers = false,
                        ._padding = 0,
                    },
                });

                if (gui.tableNextColumn()) {
                    gui.text("Rotation: {d}, {d}, {d}", .{ camera.rotation[0], camera.rotation[1], camera.rotation[2] });
                }

                gui.tableNextRow(.{
                    .min_row_height = 32,
                    .row_flags = .{
                        .headers = false,
                        ._padding = 0,
                    },
                });

                if (gui.tableNextColumn()) {
                    gui.text("Move. speed: {d}", .{camera.movement_speed});
                }

                gui.tableNextRow(.{
                    .min_row_height = 32,
                    .row_flags = .{
                        .headers = false,
                        ._padding = 0,
                    },
                });

                if (gui.tableNextColumn()) {
                    gui.text("Turn speed: {d}", .{camera.turn_speed});
                }

                gui.tableNextRow(.{
                    .min_row_height = 32,
                    .row_flags = .{
                        .headers = false,
                        ._padding = 0,
                    },
                });

                if (gui.tableNextColumn()) {
                    gui.text("Move. Type: {s}", .{switch (camera.movement_type) {
                        .Fixed => "Fixed to axes",
                        .FixedY => "Free (w/ fixed Y axis)",
                        .Free => "Free",
                    }});
                }

                gui.endTable();
            }
        }

        gui.end();

        gui.backend.draw();

        state.window.swapBuffers();

        last_interval = this_interval;
    }
}
