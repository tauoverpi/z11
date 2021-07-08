const std = @import("std");
const lib = @import("lib.zig");
const mem = std.mem;
const Allocator = std.mem.Allocator;
const types = lib.types;

const Session = @This();

pub const Setup = extern struct {
    release: u32,
    resource_id_base: u32,
    resource_id_mask: u32,
    motion_buffer_size: u32,
    length_of_vendor: u16,
    maximum_request_length: u16,
    number_of_screens: u8,
    number_of_formats: u8,
    image_byte_order: u8,
    bitmap_format_bit_order: u8,
    bitmap_format_scanline_unit: u8,
    bitmap_format_scanline_pad: u8,
    min_keycode: u8,
    max_keycode: u8,
    pad: u32,

    pub const Format = extern struct {
        depth: u8,
        bits_per_pixel: u8,
        scanline_pad: u8,
        pad: [5]u8 = [_]u8{0} ** 5,
    };

    pub const Depth = extern struct {
        depth: u8,
        pad0: u8 = 0,
        visuals_length: u16,
        pad: [4]u8 = [_]u8{0} ** 4,
    };

    pub const Visual = extern struct {
        visual: types.VisualId,
        class: u8,
        bits_per_rgb_value: u8,
        colormap_entries: u16,
        red_mask: u32,
        green_mask: u32,
        blue_mask: u32,
        pad: [4]u8 = [_]u8{0} ** 4,
    };

    pub const Screen = extern struct {
        root: types.Window,
        default_colormap: u32,
        white_pixel: u32,
        black_pixel: u32,
        input_mask: u32,
        width_pixel: u16,
        height_pixel: u16,
        width_milimeter: u16,
        height_milimiter: u16,
        min_maps: u16,
        max_maps: u16,
        root_visual: types.VisualId,
        backing_store: u8,
        save_unders: u8,
        root_depth: u8,
        allowed_depths_length: u8,
    };
};

bytes: []align(4) const u8,

pub fn setup(self: Session) *const Setup {
    return mem.bytesAsValue(Setup, self.bytes[0..@sizeOf(Setup)]);
}

pub fn vendor(self: Session) []const u8 {
    const s = self.setup();
    const size = @sizeOf(Setup);
    return self.bytes[size .. size + s.length_of_vendor];
}

pub fn formats(self: Session) []const Setup.Format {
    const s = self.setup();
    const offset = s.length_of_vendor + @sizeOf(Setup);
    const len = s.number_of_formats;
    return @ptrCast([*]const Screen.Format, &self.bytes[offset])[0..len];
}

pub fn screens(self: Session) ScreenIterator {
    const s = self.setup();
    const offset = s.length_of_vendor +
        @sizeOf(Setup) +
        @sizeOf(Setup.Format) *
        s.number_of_formats;
    return .{
        .bytes = self.bytes[offset..],
        .remain = s.number_of_screens,
    };
}

pub fn depths(self: Session, screen: *const Setup.Screen) DepthIterator {
    const offset = @ptrToInt(screen) - @ptrToInt(self.bytes.ptr);
    return DepthIterator{
        .bytes = self.bytes[offset + @sizeOf(Setup.Screen) ..],
        .remain = screen.allowed_depths_length,
    };
}

pub fn visuals(self: Session, depth: *const Setup.Depth) []const Setup.Visual {
    const offset = @ptrToInt(depth) - @ptrToInt(self.bytes.ptr);
    return @ptrCast(
        [*]const Setup.Visual,
        @alignCast(4, &self.bytes[offset + @sizeOf(Setup.Depth)]),
    )[0..depth.visuals_len];
}

pub const ScreenIterator = struct {
    bytes: []align(4) const u8,
    index: u32 = 0,
    remain: u8,

    pub fn next(self: *ScreenIterator) ?*const Setup.Screen {
        if (self.remain == 0) return null;
        defer self.remain -= 1;

        const result = @ptrCast(
            *const Setup.Screen,
            @alignCast(4, &self.bytes[self.index]),
        );

        var session: Session = .{ .bytes = self.bytes };

        var it = session.depths(result);
        while (it.next()) |depth| {
            self.index += @sizeOf(Setup.Depth) +
                depth.visuals_length * @sizeOf(Setup.Visual);
        }

        return result;
    }
};

pub const DepthIterator = struct {
    bytes: []align(4) const u8,
    index: u32 = 0,
    remain: u8,

    pub fn next(self: *DepthIterator) ?*const Setup.Depth {
        if (self.remain == 0) return null;
        defer self.remain -= 1;
        const result = @ptrCast(
            *const Setup.Depth,
            @alignCast(4, &self.bytes[self.index]),
        );

        self.index += @sizeOf(Setup.Depth) +
            result.visuals_length *
            @sizeOf(Setup.Visual);

        return result;
    }
};

pub fn deinit(self: Session, gpa: *Allocator) void {
    gpa.free(self.bytes);
}
