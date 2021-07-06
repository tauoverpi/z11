const std = @import("std");
const lib = @import("lib.zig");
const mem = std.mem;
const fmt = std.fmt;

const Reactor = std.x.os.Reactor;
const Session = lib.Session;
const XAuth = lib.XAuth;

const Gpa = std.heap.GeneralPurposeAllocator(.{});

pub const Opcode = enum(u8) {
    create_window = 1,
    map_window = 8,
};

pub const Error = extern struct {
    opcode: u8 = 0,
    code: ErrorCode,
    sequence: u16,
    bad_value: u32,
    minor_opcode: u16,
    major_opcode: Opcode,
    unused: [21]u8,

    pub const ErrorCode = enum(u8) {
        request = 1,
        value = 2,
        window = 3,
        pixmap = 4,
        atom = 5,
        cursor = 6,
        font = 7,
        match = 8,
        drawable = 9,
        access = 10,
        alloc = 11,
        colormap = 12,
        g_context = 13,
        id_choice = 14,
        name = 15,
        length = 16,
        implementation = 17,
    };
};

const CreateWindowRequest = extern struct {
    opcode: u8 = 1,
    depth: u8,
    length: u16 = 8,
    window: u32,
    parent: u32,
    x: i16,
    y: i16,
    width: u16,
    height: u16,
    class: u8,
    visual: u32,
    values: u32 = 0,
};

const MapWindowRequest = extern struct {
    opcode: u8 = 8,
    unused: u8 = 0,
    length: u16 = 2,
    window: u32,
};

pub fn main() !void {
    var allocator = Gpa{};
    defer _ = allocator.deinit();
    const gpa = &allocator.allocator;

    var it = try lib.XAuth.init(gpa);
    defer it.deinit(gpa);

    const auth = (try it.next()) orelse return error.NotAuthFound;

    var buffer: [4096]u8 = undefined;
    const request = try auth.request(&buffer);

    const stream = try std.net.connectUnixSocket("/tmp/.X11-unix/X0");
    const writer = stream.writer();
    const reader = stream.reader();
    try writer.writeAll(request);

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

    const header = try reader.readStruct(Header);
    const bytes = try gpa.allocAdvanced(u8, 4, header.length * 4, .exact);
    try reader.readNoEof(bytes);
    const session = Session{ .bytes = bytes };
    defer session.deinit(gpa);

    const screen = session.screens().next().?;
    const setup = session.setup();
    std.log.info("{s}", .{fmt.fmtSliceEscapeUpper(session.vendor())});

    std.log.info("{}", .{header});
    std.log.info("{}", .{setup});
    std.log.info("{}", .{screen});

    const w: CreateWindowRequest = .{
        .window = setup.resource_id_base,
        .parent = screen.root,
        .depth = screen.root_depth,
        .x = 0,
        .y = 0,
        .width = 100,
        .height = 100,
        .class = 0,
        .visual = screen.root_visual,
        .values = 0,
    };

    std.log.info("{}", .{w});

    const m: MapWindowRequest = .{ .window = setup.resource_id_base };

    std.log.info("{}", .{m});

    var reactor = try Reactor.init(.{ .close_on_exec = true });
    try reactor.update(stream.handle, @intCast(usize, stream.handle), .{
        .readable = true,
    });

    try writer.writeAll(mem.asBytes(&w));
    try writer.writeAll(mem.asBytes(&m));

    const Ctx = struct {
        pub fn call(self: @This(), event: Reactor.Event) !void {
            _ = self;
            const s = std.net.Stream{ .handle = @intCast(std.os.fd_t, event.data) };
            std.log.info("{}", .{try s.reader().readStruct(Error)});
            return error.FailedTest;
        }
    };

    var ctx: Ctx = .{};

    try reactor.poll(2, ctx, 0);
}
