const std = @import("std");
const lib = @import("lib.zig");
const mem = std.mem;
const fmt = std.fmt;
const meta = std.meta;
const testing = std.testing;

const Allocator = std.mem.Allocator;
const Reactor = std.x.os.Reactor;
const Session = lib.Session;
const XAuth = lib.XAuth;

const request = lib.request;

const Client = struct {
    stream: std.net.Stream,
    session: Session,

    pub fn init(gpa: *Allocator) !Client {
        var it = try lib.XAuth.init(gpa);
        defer it.deinit(gpa);

        // TODO: fix
        const auth = (try it.next()) orelse return error.NotAuthFound;
        var buffer: [4096]u8 = undefined;
        const req = try auth.request(&buffer);

        const Header = extern struct {
            status: Status,
            unused: u8,
            major: u16,
            minor: u16,
            length: u16,

            pub const Status = enum(u8) {
                setup_faied,
                ok,
                authenticate,
                _,
            };
        };

        const stream = try std.net.connectUnixSocket("/tmp/.X11-unix/X0");
        const writer = stream.writer();
        const reader = stream.reader();
        try writer.writeAll(req);

        const header = try reader.readStruct(Header);
        const bytes = try gpa.allocAdvanced(u8, 4, header.length * 4, .exact);
        try reader.readNoEof(bytes);

        return Client{
            .stream = stream,
            .session = Session{ .bytes = bytes },
        };
    }

    pub fn deinit(self: *Client, gpa: *Allocator) void {
        self.stream.close();
        self.session.deinit(gpa);
    }

    pub fn App(comptime T: type) type {
        return struct {
            client: *Client,
            application: T,

            const Self = @This();

            pub fn call(self: *Self, event: Reactor.Event) !void {
                _ = event; // TODO: handle failure
                const reader = self.client.stream.reader();
                const bytes = try reader.readBytesNoEof(32);
                switch (bytes[0]) {
                    0 => try self.dispatchErrorHandler(bytes),
                    1 => @panic("oh yes"), // reponse
                    2...34 => try self.dispatchEventHandler(bytes),
                    else => unreachable,
                }
            }

            fn dispatchErrorHandler(self: *Self, event: [32]u8) !void {
                _ = self;
                std.log.err("{}", .{@bitCast(request.Error, event)});
                return error.Error;
            }

            fn dispatchEventHandler(self: *Self, event: [32]u8) !void {
                _ = self;
                const C = T;
                switch (@intToEnum(request.Event, event[0])) {
                    .key_press => if (@hasDecl(C, "keyPressCallback"))
                        try self.application.keyPressCallback(),
                    .key_release => if (@hasDecl(C, "keyReleaseCallback"))
                        try self.application.keyReleaseCallback(),
                    .button_press => if (@hasDecl(C, "buttonPressCallback"))
                        try self.application.buttonPressCallback(),
                    .button_release => if (@hasDecl(C, "buttonReleaseCallback"))
                        try self.application.button_releaseCallback(),
                    .motion_notify => if (@hasDecl(C, "motionNotifyCallback"))
                        try self.application.motion_notifyCallback(),
                    .enter_notify => if (@hasDecl(C, "enterNotifyCallback"))
                        try self.application.enter_notifyCallback(),
                    .leave_notify => if (@hasDecl(C, "leaveNotifyCallback"))
                        try self.application.leave_notifyCallback(),
                    .focus_in => if (@hasDecl(C, "focusInCallback"))
                        try self.application.focus_inCallback(),
                    .focus_out => if (@hasDecl(C, "focusOutCallback"))
                        try self.application.focus_outCallback(),
                    .keymap_notify => if (@hasDecl(C, "keymapNotifyCallback"))
                        try self.application.keymap_notifyCallback(),
                    .expose => if (@hasDecl(C, "expose"))
                        try self.application.exposeCallback(),
                    .graphics_exposure => if (@hasDecl(C, "graphicsExposureCallback"))
                        try self.application.graphics_exposureCallback(),
                    .no_exposure => if (@hasDecl(C, "noExposureCallback"))
                        try self.application.no_exposureCallback(),
                    .visibility_notify => if (@hasDecl(C, "visibilityNotifyCallback"))
                        try self.application.visibility_notifyCallback(),
                    .create_notify => if (@hasDecl(C, "createNotifyCallback"))
                        try self.application.create_notifyCallback(),
                    .destroy_notify => if (@hasDecl(C, "destroyNotifyCallback"))
                        try self.application.destroy_notifyCallback(),
                    .unmap_notify => if (@hasDecl(C, "unmapNotifyCallback"))
                        try self.application.unmap_notifyCallback(),
                    .map_notify => if (@hasDecl(C, "mapNotifyCallback"))
                        try self.application.map_notifyCallback(),
                    .map_request => if (@hasDecl(C, "mapRequestCallback"))
                        try self.application.map_requestCallback(),
                    .reparent_notify => if (@hasDecl(C, "reparentNotifyCallback"))
                        try self.application.reparent_notifyCallback(),
                    .configure_notify => if (@hasDecl(C, "configureNotifyCallback"))
                        try self.application.configure_notifyCallback(),
                    .configure_request => if (@hasDecl(C, "configureRequestCallback"))
                        try self.application.configure_requestCallback(),
                    .gravity_notify => if (@hasDecl(C, "gravityNotifyCallback"))
                        try self.application.gravity_notifyCallback(),
                    .resize_request => if (@hasDecl(C, "resizeRequestCallback"))
                        try self.application.resize_requestCallback(),
                    .circulate_notify => if (@hasDecl(C, "circulateNotifyCallback"))
                        try self.application.circulate_notifyCallback(),
                    .circulate_request => if (@hasDecl(C, "circulateRequestCallback"))
                        try self.application.circulate_requestCallback(),
                    .property_notify => if (@hasDecl(C, "propertyNotifyCallback"))
                        try self.application.property_notifyCallback(),
                    .selection_clear => if (@hasDecl(C, "selectionClearCallback"))
                        try self.application.selection_clearCallback(),
                    .selection_request => if (@hasDecl(C, "selectionRequestCallback"))
                        try self.application.selection_requestCallback(),
                    .selection_notify => if (@hasDecl(C, "selectionNotifyCallback"))
                        try self.application.selection_notifyCallback(),
                    .colormap_notify => if (@hasDecl(C, "colormapNotifyCallback"))
                        try self.application.colormap_notifyCallback(),
                    .client_message => if (@hasDecl(C, "clientMessageCallback"))
                        try self.application.client_messageCallback(),
                    .mapping_notify => if (@hasDecl(C, "mappingNotifyCallback"))
                        try self.application.mapping_notifyCallback(),
                }
            }
        };
    }

    pub fn app(self: *Client, application: anytype) App(@TypeOf(application)) {
        return .{
            .client = self,
            .application = application,
        };
    }
};

const Async = struct {
    queue: Queue,

    const Queue = std.TailQueue(Entry);
    const Entry = struct {
        frame: anyframe,
        sequence: u16,
        opcode: request.Opcode,
        result: usize,
    };

    // resume a suspended function
    fn resumeCallback(self: *Async, sequence: u16) ?*Entry {
        var node = self.queue.first;

        while (node != null) {
            const curr = node.?;
            if (curr.data.sequence == sequence) {
                if (curr.prev) |prev| prev.next = curr.next;
                if (curr.next) |next| next.prev = curr.prev;
                return node.data;
            }
            node = node.next();
        }

        return null;
    }

    // forwarded callbacks
    pub fn keyPressCallback(_: *Async) !void {}
    pub fn keyReleaseCallback(_: *Async) !void {}

    // handled callbacks
    pub fn mapNotifyCallback(_: *Async) !void {}

    pub fn createNotifyCallback(_: *Async) !void {
        const entry = self.resumeCallback(sequence) orelse return error.NoCallbackFound;
        const loc = @intToPtr(*void, entry.result);
        loc.* = .{}; // write some data
        resume entry.frame;
    }

    pub fn destroyNotifyCallback(_: *Async) !void {}
};

test {
    const gpa = testing.allocator;

    var client = try Client.init(gpa);
    defer client.deinit(gpa);

    var thing: Thing = .{};
    var app = client.app(thing);

    const setup = client.session.setup();
    const screen = client.session.screens().next().?;
    const writer = client.stream.writer();

    var e: request.ChangeWindowAttributes = .{
        .window = screen.root,
        .length = 4,
        .value_mask = .{ .event_mask = true },
    };

    const w: request.CreateWindowRequest = .{
        .window = @intToEnum(lib.types.Window, setup.resource_id_base),
        .parent = screen.root,
        .depth = screen.root_depth,
        .x = 0,
        .y = 0,
        .width = 100,
        .height = 100,
        .class = 0,
        .visual = screen.root_visual,
        .value_mask = .{},
    };

    std.log.info("{}", .{w});

    const m: request.MapWindowRequest = .{
        .window = @intToEnum(lib.types.Window, setup.resource_id_base),
    };

    std.log.info("{}", .{m});

    var reactor = try Reactor.init(.{ .close_on_exec = true });
    try reactor.update(client.stream.handle, @intCast(usize, client.stream.handle), .{
        .readable = true,
    });

    //try writer.writeAll(mem.asBytes(&e));
    //try writer.writeIntLittle(u32, @bitCast(u32, request.EventMask{
    //.structure_notify = true,
    //.substructure_notify = true,
    //.property_change = true,
    //}));
    _ = e;

    try reactor.poll(2, &app, 100); // root

    try writer.writeAll(mem.asBytes(&w));

    try reactor.poll(2, &app, 100); // window

    try writer.writeAll(mem.asBytes(&m));

    try reactor.poll(2, &app, 100); // map
}

const Thing = struct {};
