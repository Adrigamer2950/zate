pub const LoginCompression = struct {
    pub const packet_name = "login_compression";
    pub const packet_id = 3;

    threshold: i32,

    fn init(threshold: i32) LoginCompression {
        return .{ .threshold = threshold };
    }

    pub fn decode(reader: *net.Reader) !LoginCompression {
        const threshold = try reader.readVarInt(i32);

        return .init(threshold.value);
    }

    pub fn encode(packet: LoginCompression, writer: *net.Writer) !void {
        try writer.writeVarInt(i32, packet.threshold);
    }

    pub fn handle(packet: LoginCompression, connection: *net.Connection, io: std.Io) !void {
        try protocol.sendPacket(io, connection, .{
            .direction = .clientbound,
            .state = .login,
            .id = packet_id,
            .data = .init(&packet),
        });

        connection.compression_threshold = packet.threshold;
    }
};

const net = zate.net;
const protocol = zate.protocol;
const zate = @import("../../../root.zig");

const std = @import("std");
