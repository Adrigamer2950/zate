pub const LoginAcknowledged = struct {
    pub const packet_name = "login_acknowledged";
    pub const packet_id = 3;

    pub fn decode(reader: *net.Reader, alloc: std.mem.Allocator) !LoginAcknowledged {
        _ = reader;
        _ = alloc;

        return .{};
    }

    pub fn handle(packet: LoginAcknowledged, connection: *net.Connection, io: std.Io) !void {
        try protocol.sendPacket(io, connection, .{
            .direction = .serverbound,
            .state = .login,
            .id = packet_id,
            .data = .init(&packet),
        });

        connection.switchState(.configuration);
    }
};

const net = zate.net;
const protocol = zate.protocol;
const zate = @import("../../../root.zig");

const std = @import("std");
