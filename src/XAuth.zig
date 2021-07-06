const std = @import("std");
const os = std.os;
const fs = std.fs;
const io = std.io;
const Allocator = std.mem.Allocator;

const XAuth = @This();

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

pub fn init(gpa: *Allocator) !Iterator {
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

    return Iterator{ .bytes = buffer };
}

pub const Iterator = struct {
    bytes: []const u8,
    index: usize = 0,

    pub fn next(self: *Iterator) !?XAuth {
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

    pub fn deinit(self: *Iterator, gpa: *Allocator) void {
        gpa.free(self.bytes);
        self.* = undefined;
    }
};
