pub const StatusResponse = struct {
    pub const packet_name = "status_response";
    pub const packet_id = 0;

    version: struct {
        name: []const u8,
        protocol: protocol.ProtocolVersion,
    },
    players: struct {
        max: i32,
        online: i32,
        sample: []const struct {
            name: []const u8,
            id: []const u8,
        } = &.{},
    },
    description: struct {
        text: []const u8,
    },
    favicon: ?[]const u8 = null,
    enforcesSecureChat: ?bool = null,

    pub const max_json_len = 32767;

    pub fn encode(status: StatusResponse, writer: *net.Writer) !void {
        var buf: [256]u8 = undefined;
        const json = zate.util.stringify(&buf, status, .{}) catch @panic("OOM");

        if (json.len > max_json_len) return error.ValueTooBig;

        try writer.writeString(json);
    }
};

pub const PongResponse = struct {
    pub const packet_name = "pong_response";
    pub const packet_id = 1;

    timestamp: i64,

    pub fn init(timestamp: i64) PongResponse {
        return .{ .timestamp = timestamp };
    }

    pub fn encode(response: PongResponse, writer: *net.Writer) !void {
        try writer.writeInt(i64, response.timestamp, .big);
    }
};

const net = zate.net;
const protocol = zate.protocol;
const zate = @import("../../../root.zig");

const std = @import("std");
