/// AsyncClient is a wrapper for X clients which forwards events to the client
/// while allowing a sequential style.
///
/// ```
/// const Client = AsyncClient(struct {
///     pub fn xmain(self: *Self, x11: Context) anyerror!void {
///         const window = try x11.createWindow("hi", 0, 0, 1200, 720);
///         defer window.deinit();
///
///         const gc = try window.getGraphicsContext();
///         defer gc.deinit();
///
///         try gc.setBackgroud(0);
///
///         while (true) {
///             try ctx.pollEvents();
///             // main loop code
///         }
///     }
/// });
/// ```
fn AsyncClient(comptime C: type) type {
    return struct {
        frame: @Frame(T.xmain),
        wait_queue: Queue,
        client: T,

        const T = C(Context);

        const Queue = std.TailQueue(Entry);
        const Node = Queue.Node;

        const Entry = struct {
            frame: anyframe,
        };

        const Context = struct {
            queue: *opaque {},
            pub fn yield(self: Context) void {
                suspend {
                    var frame = @frame();
                    var node: Node = .{
                        .next = undefined,
                        .prev = undefined,
                        .data = .{
                            .frame = &frame,
                        },
                    };

                    @ptrCast(*Queue, self.queue).push(&node);
                }
            }
        };

        pub inline fn requestCallback(self: *Self) !void {
            if (@hasDecl(T, "requestCallback")) {
                self.client.requestCallback();
            }
        }
    };
}

fn ExampleXApplication(comptime Context: type) type {
    return struct {
        const Self = @This();

        fn keypressCallback(self: *Self, scancode: u32, stuff: Stuff) !void {
            _ = self;
            _ = scancode;
            _ = stuff;
            @panic("oh noes");
        }

        pub fn xmain(ctx: Context) anyerror!void {
            const window = try ctx.createWindow("hello", 0, 0, 1200, 720);
            defer window.deinit();

            try window.register(.{
                .key_press = keypressCallback,
            });

            const gc = try window.createGraphicsContext();
            defer gc.deinit();

            var colour: u32 = 0x0000ff;

            while (true) {
                while (try ctx.pollEvents()) {}

                try gc.setBackground(colour);
                colour = ~colour; // ensure epileptic seizures pokemon style
            }
        }
    };
}
