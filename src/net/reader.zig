reader: *std.Io.Reader,

pub fn readByte(r: *Reader) ReaderError!u8 {
    return try r.reader.takeByte();
}

pub inline fn takeInt(r: *Reader, comptime T: type, endian: std.builtin.Endian) ReaderError!T {
    return try r.reader.takeInt(T, endian);
}

pub fn readVarInt(r: *Reader, comptime T: type) !protocol.VarInt(T) {
    var value: T = 0;
    var position: u5 = 0;
    var bytes_read: usize = 0;

    while (true) {
        const byte = try r.readByte();
        bytes_read += 1;
        value |= @as(T, byte & 0x7F) << position;
        if (byte & 0x80 == 0) break;
        position += 7;
        if (position >= 32) return error.VarIntTooBig;
    }

    return .{ .value = value, .bytes_read = bytes_read };
}

pub fn readString(r: *Reader, buffer: []u8) ReaderError![]const u8 {
    const len: usize = @intCast((try readVarInt(r, usize)).value);
    if (len > buffer.len) return ReaderError.ReadFailed;

    const slice = buffer[0..len];
    _ = try r.readSliceAll(slice);
    return slice;
}

pub fn readAndAllocString(r: *Reader, comptime max_len: u32, alloc: std.mem.Allocator) ReaderError![]const u8 {
    var buf: [max_len]u8 = undefined;
    const string = try readString(r, &buf);

    return alloc.dupe(u8, string) catch @panic("OOM");
}

pub fn readUuid(reader: *Reader) !net.Uuid {
    var buf: [16]u8 = undefined;
    try reader.reader.readSliceAll(&buf);
    return .{ .bytes = buf };
}

pub fn buffered(r: *Reader) []u8 {
    return r.reader.buffered();
}

pub fn readSliceAll(r: *Reader, buffer: []u8) ReaderError!void {
    try r.reader.readSliceAll(buffer);
}

pub fn discardAll(r: *Reader, n: usize) ReaderError!void {
    try r.reader.discardAll(n);
}

pub const Reader = @This();

const net = @import("../root.zig");
const protocol = zate.protocol;
const zate = @import("../root.zig");

const ReaderError = std.Io.Reader.Error;
const std = @import("std");
