bytes: [16]u8,

pub fn formatToString(uuid: Uuid, out: []u8) []const u8 {
    const bytes = uuid.bytes;

    return std.fmt.bufPrint(out, "{x:0>2}{x:0>2}{x:0>2}{x:0>2}-{x:0>2}{x:0>2}-{x:0>2}{x:0>2}-{x:0>2}{x:0>2}-{x:0>2}{x:0>2}{x:0>2}{x:0>2}{x:0>2}{x:0>2}", .{
        bytes[0],  bytes[1],  bytes[2],  bytes[3],
        bytes[4],  bytes[5],  bytes[6],  bytes[7],
        bytes[8],  bytes[9],  bytes[10], bytes[11],
        bytes[12], bytes[13], bytes[14], bytes[15],
    }) catch @panic("OOM");
}

pub const Uuid = @This();

const std = @import("std");
