const std = @import("std");
const zopengl = @import("zopengl");
const gl = zopengl.bindings;
const glfw = @import("zglfw");
const gui = @import("zgui");
const math = @import("zmath");
const stbi = @import("zstbi");
const arg = @import("args.zig");
const PlayerCharacter = @import("PlayerCharacter.zig").PlayerCharacter;
const Timestep = @import("Timestep.zig").Timestep;
const Chunk = @import("chunk/Chunk.zig").Chunk;
const ChunkMeshBufferPool = @import("chunk/chunkBuffer.zig").ChunkMeshBufferPool;
const chunk_mesher = @import("chunk/chunkMesher.zig");
const callbacks = @import("gl/callbacks.zig");
const ShaderProgram = @import("gl/ShaderProgram.zig").ShaderProgram;
const Bindings = @import("input/Bindings.zig").Bindings;
const MouseMovement = @import("input/MouseMovement.zig").MouseMovement;

pub const Application = struct {
    var window: *glfw.Window = undefined;
    var shader_program: ShaderProgram = undefined;
    var wireframe_enabled: bool = false;
    var show_cursor: bool = true;
    var show_debug_window: bool = false;
    var alloc: std.mem.Allocator = undefined;

    pub fn run() !void {
        var gpa = std.heap.GeneralPurposeAllocator(.{}){};
        defer _ = gpa.deinit();

        alloc = gpa.allocator();

        try init(alloc);
        defer shutdown();

        _ = try arg.GetCLArguments(alloc);

        Bindings.init(alloc);
        defer Bindings.deinit();

        try PlayerCharacter.init();

        try Bindings.registerBinding("dbg_cycleWireframe", &cycleWireframe);
        try Bindings.registerBinding("dbg_toggleDebugWindow", &toggleDebugWindow);
        try Bindings.registerBinding("dbg_reloadShader", &reloadShader);
        try Bindings.assignKey("dbg_cycleWireframe", glfw.Key.h);
        try Bindings.assignKey("dbg_toggleDebugWindow", glfw.Key.F8);
        try Bindings.assignKey("dbg_reloadShader", glfw.Key.F9);

        try Bindings.assignKey("ply_cycleCam", glfw.Key.m);
        try Bindings.assignKey("ply_cycleInputType", glfw.Key.n);
        try Bindings.assignKey("ply_moveForward", glfw.Key.w);
        try Bindings.assignKey("ply_moveBackward", glfw.Key.s);
        try Bindings.assignKey("ply_flyUp", glfw.Key.space);
        try Bindings.assignKey("ply_flyDown", glfw.Key.left_shift);
        try Bindings.assignKey("ply_strafeLeft", glfw.Key.a);
        try Bindings.assignKey("ply_strafeRight", glfw.Key.d);
        try Bindings.assignKey("ply_lookLeft", glfw.Key.left);
        try Bindings.assignKey("ply_lookRight", glfw.Key.right);
        try Bindings.assignKey("ply_lookUp", glfw.Key.up);
        try Bindings.assignKey("ply_lookDown", glfw.Key.down);

        try buildShader();
        defer shader_program.destroy();

        try ChunkMeshBufferPool.init(alloc);
        defer ChunkMeshBufferPool.deinit();
        try ChunkMeshBufferPool.addChunkInstances(alloc);

        while (!window.shouldClose()) {
            try loop();
        }
    }

    fn init(allocator: std.mem.Allocator) anyerror!void {
        try glfw.init();

        glfw.windowHintTyped(.context_version_major, 4);
        glfw.windowHintTyped(.context_version_minor, 6);
        glfw.windowHintTyped(.opengl_profile, .opengl_core_profile);
        glfw.windowHintTyped(.opengl_forward_compat, true);
        glfw.windowHintTyped(.client_api, .opengl_api);
        glfw.windowHintTyped(.doublebuffer, true);

        window = try glfw.Window.create(640, 480, "Test Window", null);

        glfw.makeContextCurrent(window);
        _ = glfw.setErrorCallback(callbacks.glfwErrorCallback);
        _ = window.setFramebufferSizeCallback(callbacks.glfwSizeCallback);
        _ = window.setCursorPosCallback(MouseMovement.glfwCursorPosCallback);
        _ = window.setKeyCallback(Bindings.glfwKeyCallback);

        if (glfw.rawMouseMotionSupported()) {
            window.setInputMode(.raw_mouse_motion, true);
        }

        glfw.swapInterval(1);

        try zopengl.loadCoreProfile(glfw.getProcAddress, 4, 6);

        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST);
        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR);

        gl.enable(gl.DEBUG_OUTPUT);
        gl.debugMessageCallback(callbacks.glMessageCallback, null);

        gl.enable(gl.BLEND);
        gl.blendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA);
        gl.enable(gl.DEPTH_TEST);
        gl.enable(gl.CULL_FACE);
        gl.cullFace(gl.BACK);
        gl.clearColor(0.2, 0.2, 0.2, 1.0);
        gl.viewport(0, 0, 640, 480);

        stbi.init(allocator);

        gui.init(allocator);
        gui.backend.init(window);
    }

    fn shutdown() void {
        gui.backend.deinit();
        gui.deinit();
        stbi.deinit();
        window.destroy();
        glfw.terminate();
    }

    fn loop() !void {
        Timestep.nextFrame();

        glfw.pollEvents();

        PlayerCharacter.update();

        const mvp = PlayerCharacter.camera.getMvpMatrix(window);

        try shader_program.setUniformMatrix("u_model_view_project", 4, 4, 1, false, f32, math.arrNPtr(&mvp));
        gl.uniform1i(1, 0);

        gl.clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);

        shader_program.use();

        ChunkMeshBufferPool.draw();

        drawDebugWindow();

        window.swapBuffers();
    }

    fn drawDebugWindow() void {
        if (show_debug_window) {
            const fb_size = window.getFramebufferSize();

            gui.backend.newFrame(@intCast(fb_size[0]), @intCast(fb_size[1]));

            if (gui.begin("Test window", .{ .flags = .{ .no_saved_settings = true }, .popen = &show_debug_window })) {
                gui.bulletText("Hello world!", .{});
                gui.bulletText("FPS: {d:0>2.4}", .{Timestep.get()});

                if (gui.beginTabBar("", .{})) {
                    if (gui.beginTabItem("Data", .{})) {
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
                                gui.text("Wireframe: {s}", .{if (wireframe_enabled) "Yes" else "No"});
                            }

                            gui.tableNextRow(.{
                                .min_row_height = 32,
                                .row_flags = .{
                                    .headers = false,
                                    ._padding = 0,
                                },
                            });

                            if (gui.tableNextColumn()) {
                                gui.text("Position: {d}, {d}, {d}", .{ PlayerCharacter.camera.position[0], PlayerCharacter.camera.position[1], PlayerCharacter.camera.position[2] });
                            }

                            gui.tableNextRow(.{
                                .min_row_height = 32,
                                .row_flags = .{
                                    .headers = false,
                                    ._padding = 0,
                                },
                            });

                            if (gui.tableNextColumn()) {
                                gui.text("Rotation: {d}, {d}, {d}", .{ PlayerCharacter.camera.rotation[0], PlayerCharacter.camera.rotation[1], PlayerCharacter.camera.rotation[2] });
                            }

                            gui.tableNextRow(.{
                                .min_row_height = 32,
                                .row_flags = .{
                                    .headers = false,
                                    ._padding = 0,
                                },
                            });

                            if (gui.tableNextColumn()) {
                                gui.text("Move. speed: {d}", .{PlayerCharacter.move_speed});
                            }

                            gui.tableNextRow(.{
                                .min_row_height = 32,
                                .row_flags = .{
                                    .headers = false,
                                    ._padding = 0,
                                },
                            });

                            if (gui.tableNextColumn()) {
                                gui.text("Turn speed: {d}", .{PlayerCharacter.turn_speed});
                            }

                            gui.tableNextRow(.{
                                .min_row_height = 32,
                                .row_flags = .{
                                    .headers = false,
                                    ._padding = 0,
                                },
                            });

                            if (gui.tableNextColumn()) {
                                gui.text("Move. Type: {s}", .{switch (PlayerCharacter.camera.movement_type) {
                                    .FixedY => "Free (w/ fixed Y axis)",
                                    .Free => "Free",
                                }});
                            }

                            gui.tableNextRow(.{
                                .min_row_height = 32,
                                .row_flags = .{
                                    .headers = false,
                                    ._padding = 0,
                                },
                            });

                            if (gui.tableNextColumn()) {
                                gui.text("Show Cursor?: {s}", .{if (show_cursor) "Yes" else "No"});
                            }

                            // gui.tableNextRow(.{
                            //     .min_row_height = 32,
                            //     .row_flags = .{
                            //         .headers = false,
                            //         ._padding = 0,
                            //     },
                            // });

                            // if (gui.tableNextColumn()) {
                            //     _ = gui.sliderScalar("Sensitivity", f64, .{ .v = &Input.movement_sensitivity, .min = 0.001, .max = 0.1 });
                            // }

                            gui.endTable();
                        }

                        gui.endTabItem();
                    }

                    gui.endTabBar();
                }
            }

            gui.end();

            gui.backend.draw();
        }
    }

    fn buildShader() !void {
        shader_program = try ShaderProgram.create(alloc);
        try shader_program.attach(.{
            .AsFile = .{
                .file_path = "assets/shaders/voxel.vert",
                // .file_path = "assets/shaders/test.vert",
                .target = .Vertex,
            },
        });
        try shader_program.attach(.{
            .AsFile = .{
                .file_path = "assets/shaders/voxel.frag",
                // .file_path = "assets/shaders/test.frag",
                .target = .Fragment,
            },
        });
        try shader_program.link();
    }

    fn reloadShader(_: *glfw.Window, _: []const u8, _: glfw.Key, action: glfw.Action, _: glfw.Mods) void {
        if (action == .press) {
            shader_program.destroy();
            buildShader() catch {
                std.log.err("Could not reload shader!", .{});
                std.process.exit(3);
            };
        }
    }

    fn toggleDebugWindow(_: *glfw.Window, _: []const u8, _: glfw.Key, action: glfw.Action, _: glfw.Mods) void {
        if (action == .press) {
            show_debug_window = !show_debug_window;
        }
    }

    fn cycleWireframe(_: *glfw.Window, _: []const u8, _: glfw.Key, action: glfw.Action, _: glfw.Mods) void {
        if (action == .press) {
            wireframe_enabled = !wireframe_enabled;

            if (wireframe_enabled) {
                gl.polygonMode(gl.FRONT_AND_BACK, gl.LINE);
            } else {
                gl.polygonMode(gl.FRONT_AND_BACK, gl.FILL);
            }
        }
    }
};
