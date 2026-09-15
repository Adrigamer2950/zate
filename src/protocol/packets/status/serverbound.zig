pub const StatusRequest = struct {
    pub const packet_name = "status_request";
    pub const packet_id = 0;

    pub fn decode(reader: *std.Io.Reader) !StatusRequest {
        _ = reader;

        return .{};
    }

    pub fn handle(packet: StatusRequest, connection: *net.Connection, io: std.Io) !void {
        _ = packet;

        const response: root.Clientbound.StatusResponse = .{
            .version = .{
                .name = zate.config.status.version.name,
                .protocol = if (zate.config.status.version.protocol == .none) connection.protocol_version else zate.config.status.version.protocol,
            },
            .players = zate.config.status.players,
            .description = zate.config.status.description,
            .favicon = zate.config.status.favicon,
            .enforcesSecureChat = zate.config.status.enforcesSecureChat,
        };

        try protocol.sendPacket(io, connection, .{
            .direction = .clientbound,
            .state = connection.state,
            .id = root.Clientbound.StatusResponse.packet_id,
            .data = .init(&response),
        });
    }
};

pub const PingRequest = struct {
    pub const packet_name = "ping_request";
    pub const packet_id = 1;

    timestamp: i64,

    pub fn init(timestamp: i64) PingRequest {
        return .{ .timestamp = timestamp };
    }

    pub fn decode(reader: *std.Io.Reader) !PingRequest {
        return .init(try reader.takeInt(i64, .big));
    }

    pub fn encode(response: PingRequest, writer: *std.Io.Writer) !void {
        try writer.writeInt(i64, response.timestamp, .big);
    }

    pub fn handle(packet: PingRequest, connection: *net.Connection, io: std.Io) !void {
        const response: root.Clientbound.PongResponse = .init(packet.timestamp);

        try protocol.sendPacket(io, connection, .{
            .direction = .clientbound,
            .state = connection.state,
            .id = root.Clientbound.PongResponse.packet_id,
            .data = .init(&response),
        });
    }
};

const net = zate.net;
const protocol = zate.protocol;
const zate = @import("../../../root.zig");

const root = @import("root.zig");

const std = @import("std");
