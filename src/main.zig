const std = @import("std");
const io = std.io;
const os = std.os;
const fs = std.fs;
const fmt = std.fmt;
const mem = std.mem;
const testing = std.testing;
const assert = std.debug.assert;

const Allocator = std.mem.Allocator;
const Reactor = std.x.os.Reactor;

const XAuth = struct {
    family: Family,
    address: []const u8,
    number: []const u8,
    name: []const u8,
    data: []const u8,

    pub const Family = enum(u16) {
        ip_address = 0,
        localhost = 252,
        krb5 = 253,
        netname = 254,
        local = 256,
        wild = 65535,
        _,
    };

    fn pad(n: usize) usize {
        return @bitCast(usize, (-%@bitCast(isize, n)) & 3);
    }

    pub fn size(self: XAuth) usize {
        const header_size = 14;
        return header_size +
            self.name.len +
            self.data.len +
            pad(self.data.len);
    }

    const Header = extern struct {
        order: u8 = 'l',
        unused: u8 = '0',
        major: u16 = 11,
        minor: u16 = 0,
        name_len: u16,
        data_len: u16,
        pad: u16 = 0,
    };

    pub fn request(self: XAuth, buffer: []u8) ![]const u8 {
        var fbs = io.fixedBufferStream(buffer);
        const writer = fbs.writer();

        try writer.writeStruct(Header{
            .name_len = @intCast(u16, self.name.len),
            .data_len = @intCast(u16, self.data.len),
        });

        try writer.writeAll(self.name);
        try writer.writeIntLittle(u16, 0);
        try writer.writeAll(self.data);
        try writer.writeByteNTimes(0, pad(self.data.len));

        return fbs.getWritten();
    }
};

const XAuthIterator = struct {
    bytes: []const u8,
    index: usize = 0,

    fn init(gpa: *Allocator) !XAuthIterator {
        const file = if (os.getenv("XAUTHORITY")) |name|
            try fs.openFileAbsolute(name, .{})
        else blk: {
            const home = os.getenv("HOME") orelse return error.HomeNotFound;
            var dir = try fs.cwd().openDir(home, .{});
            defer dir.close();
            break :blk try dir.openFile(".Xauthority", .{});
        };

        defer file.close();

        const stat = try file.stat();

        const buffer = try gpa.alloc(u8, stat.size);
        errdefer gpa.free(buffer);

        if ((try file.read(buffer)) != buffer.len) return error.Failed;

        return XAuthIterator{ .bytes = buffer };
    }

    pub fn next(self: *XAuthIterator) !?XAuth {
        var fbs = io.fixedBufferStream(self.bytes);
        fbs.pos = self.index;

        const reader = fbs.reader();

        const family = reader.readIntBig(u16) catch return null;

        var len = try reader.readIntBig(u16);
        const address = self.bytes[fbs.pos .. fbs.pos + len];
        try reader.skipBytes(address.len, .{});

        len = try reader.readIntBig(u16);
        const number = self.bytes[fbs.pos .. fbs.pos + len];
        try reader.skipBytes(number.len, .{});

        len = try reader.readIntBig(u16);
        const name = self.bytes[fbs.pos .. fbs.pos + len];
        try reader.skipBytes(name.len, .{});

        len = try reader.readIntBig(u16);
        const data = self.bytes[fbs.pos .. fbs.pos + len];
        try reader.skipBytes(data.len, .{});

        self.index = fbs.pos;

        return XAuth{
            .family = @intToEnum(XAuth.Family, family),
            .address = address,
            .number = number,
            .name = name,
            .data = data,
        };
    }

    pub fn deinit(self: *XAuthIterator, gpa: *Allocator) void {
        gpa.free(self.bytes);
        self.* = undefined;
    }
};

const types = struct {
    pub const Event = enum(u32) {
        key_press = 0x00000001,
        key_release = 0x00000002,
        button_press = 0x00000004,
        button_release = 0x00000008,
        enter_window = 0x00000010,
        leave_window = 0x00000020,
        pointer_motion = 0x00000040,
        pointer_motion_hint = 0x00000080,
        button1_motion = 0x00000100,
        button2_motion = 0x00000200,
        button3_motion = 0x00000400,
        button4_motion = 0x00000800,
        button5_motion = 0x00001000,
        button_motion = 0x00002000,
        keymap_state = 0x00004000,
        exposure = 0x00008000,
        visibility_change = 0x00010000,
        structure_notify = 0x00020000,
        resize_redirect = 0x00040000,
        substructure_notify = 0x00080000,
        substructure_redirect = 0x00100000,
        focus_change = 0x00200000,
        property_change = 0x00400000,
        colormap_change = 0x00800000,
        owner_grab_button = 0x01000000,
        unused = 0xFE000000,
    };

    pub const PointerEvent = enum(u32) {
        button_press,
        button_release,
        enter_window,
        leave_window,
        pointer_motion,
        pointer_motion_hint,
        button1_motion,
        button2_motion,
        button3_motion,
        button4_motion,
        button5_motion,
        button_motion,
        keymap_state,
    };

    pub const DeviceEvent = enum(u32) {
        key_press,
        key_release,
        button_press,
        button_release,
        pointer_motion,
        button1_motion,
        button2_motion,
        button3_motion,
        button4_motion,
        button5_motion,
        button_motion,
    };

    pub const Atom = enum(u16) {
        primary = 1,
        secondary = 2,
        arc = 3,
        atom = 4,
        bitmap = 5,
        cardinal = 6,
        colormap = 7,
        cursor = 8,
        cut_buffer0 = 9,
        cut_buffer1 = 10,
        cut_buffer2 = 11,
        cut_buffer3 = 12,
        cut_buffer4 = 13,
        cut_buffer5 = 14,
        cut_buffer6 = 15,
        cut_buffer7 = 16,
        drawable = 17,
        font = 18,
        integer = 19,
        pixmap = 20,
        point = 21,
        rectangle = 22,
        resource_manager = 23,
        rgb_color_map = 24,
        rgb_best_map = 25,
        rgb_blue_map = 26,
        rgb_default_map = 27,
        rgb_gray_map = 28,
        rgb_green_map = 29,
        rgb_red_map = 30,
        string = 31,
        visualid = 32,
        window = 33,
        wm_command = 34,
        wm_hints = 35,
        wm_client_machine = 36,
        wm_icon_name = 37,
        wm_icon_size = 38,
        wm_name = 39,
        wm_normal_hints = 40,
        wm_size_hints = 41,
        wm_zoom_hints = 42,
        min_space = 43,
        norm_space = 44,
        max_space = 45,
        end_space = 46,
        superscript_x = 47,
        superscript_y = 48,
        subscript_x = 49,
        subscript_y = 50,
        underline_position = 51,
        underline_thickness = 52,
        strikeout_ascent = 53,
        strikeout_descent = 54,
        italic_angle = 55,
        x_height = 56,
        quad_width = 57,
        weight = 58,
        point_size = 59,
        resolution = 60,
        copyright = 61,
        notice = 62,
        font_name = 63,
        family_name = 64,
        full_name = 65,
        cap_height = 66,
        wm_class = 67,
        wm_transient_for = 68,
    };

    pub const Window = enum(u32) { _ };
    pub const Pixmap = enum(u32) { _ };
    pub const Cursor = enum(u32) { _ };
    pub const Font = enum(u32) { _ };
    pub const GContext = enum(u32) { _ };
    pub const Colormap = enum(u32) { _ };
    pub const Drawable = enum(u32) { _ };
    pub const Fontable = enum(u32) { _ };
    pub const VisualId = enum(u32) { _ };
    pub const Value = enum(u32) { _ };
    pub const Timestamp = enum(u32) { _ };
    pub const KeySym = enum(u32) { _ };
    pub const KeyCode = enum(u8) { _ };
    pub const Button = enum(u8) { _ };
    pub const KeyMask = enum(u32) { // TODO: verify
        shift,
        lock,
        control,
        mod1,
        mod2,
        mod3,
        mod4,
        mod5,
    };

    pub const ButMask = enum(u32) { // TODO: verify
        button1,
        button2,
        button3,
        button4,
        button5,
    };

    pub const KeyButMask = extern union {
        key_mask: KeyMask,
        button_mask: ButMask,
    };

    pub const Point = extern struct {
        x: i16,
        y: i16,
    };

    pub const Rectangle = extern struct {
        x: i16,
        y: i16,
        width: u16,
        height: u16,
    };

    pub const Arc = extern struct {
        x: i16,
        y: i16,
        width: u16,
        height: u16,
        angle1: i16,
        angle2: i16,
    };

    pub const BitGravity = enum(u8) {
        forget,
        static,
        north_west,
        north,
        north_east,
        west,
        center,
        east,
        south_west,
        south,
        south_east,
    };
    pub const WinGravity = enum(u8) {
        unmap,
        static,
        north_west,
        north,
        north_east,
        west,
        center,
        east,
        south_west,
        south,
        south_east,
    };
};

const protocol = struct {
    pub const Setup = extern struct {
        release_number: u32,
        resource_id_base: u32,
        resource_id_mask: u32,
        motion_buffer_size: u32,
        vendor_len: u16,
        maximum_request_length: u16,
        roots_len: u8,
        pixmap_formats_len: u8,
        image_byte_order: Order,
        bitmap_format_bit_order: Order,
        bitmap_format_scanline_unit: u8,
        bitmap_format_scanline_pat: u8,
        min_keycode: types.KeyCode,
        max_keycode: types.KeyCode,
        pad1: [4]u8,

        pub const Order = enum(u8) { lsb, msb };
    };

    pub const Format = extern struct {
        depth: u8,
        bits_per_pixel: u8,
        scanline_pad: u8,
        pad0: [5]u8,
    };

    pub const Screen = extern struct {
        root: types.Window,
        default_colormap: types.Colormap,
        white_pixel: u32,
        black_pixel: u32,
        current_input_mask: u32,
        width_pixel: u16,
        height_pixel: u16,
        witdth_milimeter: u16,
        height_milimeter: u16,
        min_installed_maps: u16,
        max_installed_maps: u16,
        root_visual: types.VisualId,
        backing_store: BackingStores,
        save_unders: u8,
        root_depth: u8,
        allowed_depths_len: u8,

        pub const BackingStores = enum(u8) {
            never,
            when_mapped,
            always,
        };

        pub const Depth = extern struct {
            depth: u8,
            pad0: u8,
            visuals_len: u16,
            pad1: [4]u8,
        };

        pub const Visual = extern struct {
            visual_id: u32,
            class: Class,
            bits_per_rgb_value: u8,
            colormap_entries: u16,
            red_mask: u32,
            green_mask: u32,
            blue_mask: u32,
            pad0: [4]u8,

            pub const Class = enum(u8) {
                static_gray,
                static_color,
                true_color,
                gray_scale,
                pseudo_color,
                direct_color,
            };
        };
    };
};

const x11 = struct {
    pub const Error = extern struct {
        opcode: u8 = 0,
        code: ErrorCode,
        sequence: u16,
        bad_value: u32,
        minor_opcode: u16,
        major_opcode: u8,
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

    pub const request = struct {
        pub const Opcode = enum(u8) {
            create_window = 1,
        };

        pub const CreateWindow = extern struct {
            opcode: Opcode = .create_window,
            depth: u8,
            request_length: u16 = 8,
            id: types.Window,
            parent: types.Window,
            x: i16,
            y: i16,
            width: u16,
            height: u16,
            border_width: u16,
            class: Class,
            value_mask: Bitmask,

            comptime {
                assert(@bitSizeOf(Bitmask) == 32);
            }

            pub const Bitmask = packed struct {
                background_pixmap: bool = false,
                background_pixel: bool = false,
                border_pixmap: bool = false,
                border_pixel: bool = false,

                bit_gravity: bool = false,
                /// Input window only
                win_gravity: bool = false,
                backing_store: bool = false,
                backing_planes: bool = false,

                backing_pixel: bool = false,
                save_under: bool = false,
                /// Input window only
                event_mask: bool = false,
                /// Input window only
                do_not_propagate_mask: bool = false,

                /// Input window only
                override_redirect: bool = false,
                colormap: bool = false,
                cursor: bool = false,
                pad0: u1 = 0,
                pad1: u16 = 0,
            };

            pub const Class = enum(u16) {
                input_output,
                input_only,
                copy_from_parent,
            };
        };
    };

    pub const reply = struct {};
};

const xc_misc = struct {
    pub const request = struct {
        pub const GetVersion = extern struct { major: u16, minor: u16 };
        pub const GetXIDRange = extern struct { start_id: u32, count: u32 };
        pub const GetXIDList = opaque {};
    };
};

const Session = struct {
    bytes: []align(4) const u8,
    formats_offset: u32,
    screens_offset: u32,

    pub fn setup(self: Session) *const protocol.Setup {
        return mem.bytesAsValue(protocol.Setup, self.bytes[0..@sizeOf(protocol.Setup)]);
    }

    pub fn vendor(self: Session) []const u8 {
        const s = self.setup();
        const size = @sizeOf(protocol.Setup);
        return self.bytes[size .. size + s.vendor_len];
    }

    pub fn formats(self: Session) []const protocol.Format {
        const s = self.setup();
        return @ptrCast(
            [*]const protocol.Format,
            &self.bytes[self.formats_offset],
        )[0..s.pixmap_formats_len];
    }

    pub fn screens(self: Session) ScreenIterator {
        const s = self.setup();
        return ScreenIterator{
            .bytes = self.bytes[self.screens_offset..],
            .remain = s.roots_len,
        };
    }

    pub fn depths(self: Session, screen: *const protocol.Screen) DepthIterator {
        const offset = @ptrToInt(screen) - @ptrToInt(self.bytes.ptr);
        return DepthIterator{
            .bytes = self.bytes[offset + @sizeOf(protocol.Screen) ..],
            .remain = screen.allowed_depths_len,
        };
    }

    pub fn visuals(self: Session, depth: *const protocol.Screen.Depth) []const protocol.Screen.Visual {
        const offset = @ptrToInt(depth) - @ptrToInt(self.bytes.ptr);
        return @ptrCast(
            [*]const protocol.Screen.Visual,
            @alignCast(4, &self.bytes[offset + @sizeOf(protocol.Screen.Depth)]),
        )[0..depth.visuals_len];
    }

    const ScreenIterator = struct {
        bytes: []align(4) const u8,
        index: u32 = 0,
        remain: u8,

        pub fn next(self: *ScreenIterator) ?*const protocol.Screen {
            if (self.remain == 0) return null;
            defer self.remain -= 1;

            const result = @ptrCast(*const protocol.Screen, @alignCast(4, &self.bytes[self.index]));

            var session: Session = .{
                .bytes = self.bytes,
                .formats_offset = undefined,
                .screens_offset = undefined,
            };

            var it = session.depths(result);
            while (it.next()) |depth| {
                self.index += @sizeOf(protocol.Screen.Depth) +
                    depth.visuals_len * @sizeOf(protocol.Screen.Visual);
            }

            return result;
        }
    };

    const DepthIterator = struct {
        bytes: []align(4) const u8,
        index: u32 = 0,
        remain: u8,

        pub fn next(self: *DepthIterator) ?*const protocol.Screen.Depth {
            if (self.remain == 0) return null;
            defer self.remain -= 1;
            const result = @ptrCast(*const protocol.Screen.Depth, @alignCast(4, &self.bytes[self.index]));
            self.index += @sizeOf(protocol.Screen.Depth) + result.visuals_len * @sizeOf(protocol.Screen.Visual);
            return result;
        }
    };

    pub fn deinit(self: Session, gpa: *Allocator) void {
        gpa.free(self.bytes);
    }
};

/// XClient dispatches calls to methods defined within the passed struct
///
/// Hande some stuff
/// ```
/// pub fn handleSomeEvent(self: *T, args: Arg) !void;
/// ```
fn XClient(comptime T: type) type {
    return struct {
        stream: std.net.Stream,
        client: T,
        session: Session,

        const Self = @This();

        pub fn connect(gpa: *Allocator, client: T) !Self {
            const log = std.log.scoped(.x11_connect);

            var it = try XAuthIterator.init(gpa);
            defer it.deinit(gpa);

            // TODO: validate hostname
            const auth = (try it.next()) orelse return error.NoXAuthFound;

            log.debug("xauth hostname:{s} display:{s} method:{s} data:{s}", .{
                auth.address,
                auth.number,
                auth.name,
                fmt.fmtSliceHexUpper(auth.data),
            });

            var auth_buffer = try gpa.alloc(u8, auth.size());
            defer gpa.free(auth_buffer);

            const request = try auth.request(auth_buffer);

            const stream = try std.net.connectUnixSocket("/tmp/.X11-unix/X0");
            const writer = stream.writer();
            const reader = stream.reader();

            try writer.writeAll(request);

            const Header = extern struct {
                status: Status,
                pad: [5]u8,
                length: u16,

                pub const Status = enum(u8) {
                    setup_faied,
                    ok,
                    authenticate,
                    _,
                };
            };

            const header = try reader.readStruct(Header);

            const session = try gpa.allocAdvanced(u8, 4, header.length * 4, .exact);

            try reader.readNoEof(session);

            // get pointers to data blocks
            const info = blk: {
                var fbs = io.fixedBufferStream(session);
                const r = fbs.reader();

                try r.skipBytes(@sizeOf(protocol.Setup), .{});

                const vendor_len = mem.readIntSliceNative(u16, session[@offsetOf(protocol.Setup, "vendor_len")..]);
                try r.skipBytes(vendor_len, .{});

                const pixmap_offset = session[@offsetOf(protocol.Setup, "pixmap_formats_len")..];
                const pixmap_formats_len = mem.readIntSliceNative(u8, pixmap_offset);
                const formats = fbs.pos;
                try r.skipBytes(@sizeOf(protocol.Format) * pixmap_formats_len, .{});

                const screens = fbs.pos;

                break :blk .{
                    .formats = @intCast(u32, formats),
                    .screens = @intCast(u32, screens),
                };
            };
            _ = info;

            return Self{
                .stream = stream,
                .client = client,
                .session = Session{
                    .bytes = session,
                    .formats_offset = info.formats,
                    .screens_offset = info.screens,
                },
            };
        }

        pub fn call(self: *Self, event: Reactor.Event) !void {
            _ = event;
            try self.dispatch();
        }

        pub fn dispatch(self: *Self) !void {
            switch (byte) {
                .request => if (@hasDecl(T, "request")) self.client.request(),
                .request => if (@hasDecl(T, "request")) self.client.request(),
                .request => if (@hasDecl(T, "request")) self.client.request(),
                // ..
            }
        }

        pub fn close(self: *Self, gpa: *Allocator) void {
            self.stream.close();
            gpa.free(self.session.bytes);
            self.* = undefined;
        }
    };
}

test "open a window" {
    const gpa = testing.allocator;
    var client = try XClient(struct {}).connect(gpa, .{});
    defer client.close(gpa);

    const setup = client.session.setup();
    const screen = client.session.screens().next().?;
    std.log.info("{}", .{setup});

    const id = @bitCast(i32, setup.resource_id_mask) & -@bitCast(i32, setup.resource_id_mask);

    std.log.info("id: {}", .{id});

    const cw: x11.request.CreateWindow = .{
        .id = @intToEnum(types.Window, setup.resource_id_base),
        .parent = screen.root,
        .class = .input_output,
        .depth = screen.root_depth,
        .x = 1,
        .y = 1,
        .width = 1200,
        .height = 720,
        .border_width = 0,
        .value_mask = .{},
    };

    try client.stream.writer().writeAll(mem.asBytes(&cw));

    try std.x.os.Socket.from(client.stream.handle).setReadTimeout(10);

    try testing.expectError(
        error.WouldBlock,
        client.stream.reader().readBytesNoEof(32),
    );
}

pub fn main() anyerror!void {
    const gpa = std.heap.page_allocator;

    // cleaned up on exit
    var client = try XClient(struct {}).connect(gpa, .{});
    _ = client;

    //const setup = client.session.setup();

    //var reactor = try Reactor.init(.{ .close_on_exec = true });

    //try reactor.update(client.stream.handle, 0, .{});

    //while (true) try reactor.poll(32, &client, 0);
}
