const log = std.log.scoped(.@"zate::protocol");

pub const CustomPayload = struct {
    pub const packet_name = "custom_payload";
    pub const packet_id = 1;

    namespace: []const u8,
    data: []u8,

    pub const max_len = 32767;

    pub fn init(namespace: []const u8, data: []u8) CustomPayload {
        return .{
            .namespace = namespace,
            .data = data,
        };
    }

    pub fn decode(reader: *net.Reader, alloc: std.mem.Allocator) !CustomPayload {
        const namespace = try reader.readAndAllocString(max_len, alloc);
        const data = try reader.readAndAllocString(max_len, alloc);

        return .init(namespace, @constCast(data));
    }

    pub fn encode(payload: CustomPayload, writer: *net.Writer) !void {
        try writer.writeString(payload.namespace);

        if (std.mem.eql(u8, payload.namespace, "minecraft:brand")) {
            var buf: [32]u8 = undefined;
            const brand = std.fmt.bufPrint(&buf, "Zate ({s})", .{payload.data}) catch @panic("OOM");
            try writer.writeString(brand);
        } else {
            try writer.writeString(payload.data);
        }
    }
};

const net = zate.net;
const zate = @import("../../../root.zig");

const std = @import("std");
