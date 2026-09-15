const log = std.log.scoped(.@"zate::protocol");

pub const Intention = struct {
    pub const packet_name = "intention";
    pub const packet_id = 0;

    protocol_version: protocol.ProtocolVersion,
    server_address: []const u8,
    server_port: u16,
    intent: Intent,

    pub const Intent = enum(u2) {
        status = 1,
        login = 2,
        transfer = 3,
    };

    pub const max_server_address_len = 255;

    fn init(
        protocol_version: protocol.ProtocolVersion,
        server_address: []const u8,
        server_port: u16,
        intent: Intent,
    ) !Intention {
        if (server_address.len > max_server_address_len) return error.ValueTooBig;

        return .{
            .protocol_version = protocol_version,
            .server_address = server_address,
            .server_port = server_port,
            .intent = intent,
        };
    }

    pub fn decode(
        reader: *net.Reader,
        alloc: std.mem.Allocator,
    ) !Intention {
        const protocol_num = try reader.readVarInt(i32);
        const protocol_version: protocol.ProtocolVersion = @enumFromInt(protocol_num.value);

        const server_address = try reader.readAndAllocString(max_server_address_len, alloc);

        const server_port = try reader.readInt(u16, .big);

        const intent_num = try reader.readVarInt(u32);
        const intent: Intent = @enumFromInt(intent_num.value);

        return .init(protocol_version, server_address, server_port, intent);
    }

    pub fn encode(packet: Intention, writer: *net.Writer) !void {
        try writer.writeVarInt(i32, @intFromEnum(packet.protocol_version));
        try writer.writeString(packet.server_address);
        try writer.writeInt(u16, packet.server_port, .big);
        try writer.writeVarInt(u32, @intFromEnum(packet.intent));
    }

    pub fn handle(packet: Intention, connection: *net.Connection, io: std.Io) !void {
        log.debug("handshake: protocol={d} addr={s} port={d} intent={t}", .{
            @intFromEnum(packet.protocol_version),
            packet.server_address,
            packet.server_port,
            packet.intent,
        });

        connection.protocol_version = packet.protocol_version;

        switch (packet.intent) {
            .status => connection.switchState(.status),
            .login, .transfer => {
                if (connection.backend_stream == null)
                    try connection.createBackendStream(io);

                try protocol.sendPacket(io, connection, .{
                    .direction = .serverbound,
                    .state = .handshake,
                    .id = packet_id,
                    .data = .init(&packet),
                });

                connection.switchState(.login);
            },
        }
    }
};

const net = zate.net;
const protocol = zate.protocol;
const zate = @import("../../../root.zig");

const std = @import("std");
