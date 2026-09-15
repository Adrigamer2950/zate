writer: *std.Io.Writer,

pub fn writeByte(w: *Writer, byte: u8) WriterError!void {
    try w.writer.writeByte(byte);
}

pub inline fn writeInt(
    w: *Writer,
    comptime T: type,
    value: T,
    endian: std.builtin.Endian,
) WriterError!void {
    try w.writer.writeInt(T, value, endian);
}

pub fn writeVarInt(w: *Writer, comptime T: type, value_in: T) !void {
    const UnsignedT = std.meta.Int(.unsigned, @bitSizeOf(T));
    var value: UnsignedT = @bitCast(value_in);

    while (true) {
        const byte: u8 = @truncate(value & 0x7F);
        value >>= 7;

        if (value == 0) {
            try w.writeByte(byte);
            break;
        } else {
            try w.writeByte(byte | 0x80);
        }
    }
}

pub fn writeString(w: *Writer, str: []const u8) WriterError!void {
    try w.writeVarInt(u32, @intCast(str.len));
    try w.writeAll(str);
}

pub fn writeAll(w: *Writer, bytes: []const u8) WriterError!void {
    try w.writer.writeAll(bytes);
}

pub fn buffered(w: *Writer) []u8 {
    return w.writer.buffered();
}

pub fn flush(w: *Writer) WriterError!void {
    try w.writer.flush();
}

pub const Writer = @This();

const net = zate.net;
const protocol = zate.protocol;
const zate = @import("../root.zig");

const WriterError = std.Io.Writer.Error;
const std = @import("std");
