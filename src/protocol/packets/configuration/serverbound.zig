pub const FinishConfigurationAck = struct {
    pub const packet_name = "finish_configuration";
    pub const packet_id = 3;

    pub fn decode() !FinishConfigurationAck {
        return .{};
    }

    pub fn handle(packet: FinishConfigurationAck, connection: *net.Connection, io: std.Io) !void {
        try protocol.sendPacket(io, connection, .{
            .direction = .serverbound,
            .state = .configuration,
            .id = packet_id,
            .data = .init(&packet),
        });

        connection.switchState(.play);
    }
};

const net = zate.net;
const protocol = zate.protocol;
const zate = @import("../../../root.zig");

const std = @import("std");
