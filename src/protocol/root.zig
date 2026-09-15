pub fn VarInt(comptime T: type) type {
    return struct { value: T, bytes_read: usize };
}
pub const Uuid = @import("uuid.zig");

const @"packet.zig" = @import("packet.zig");
pub const Packets = @"packet.zig".Packets;
pub const Packet = @"packet.zig".Packet;
pub const PacketDirection = @"packet.zig".PacketDirection;
pub const dispatchPacket = @"packet.zig".dispatchPacket;
pub const sendPacket = @"packet.zig".sendPacket;

pub const ProtocolVersion = enum(i32) {
    none = -1,
    _,
};

test {
    _ = @"packet.zig";
}
