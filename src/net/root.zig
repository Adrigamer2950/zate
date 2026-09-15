pub const Connection = @import("connection.zig");
pub const ConnectionState = enum(u8) {
    handshake,
    status,
    login,
    configuration,
    play,
};

pub const Reader = @import("reader.zig");
pub const Writer = @import("writer.zig");

const @"receiver.zig" = @import("receiver.zig");
pub const receivePackets = @"receiver.zig".receivePackets;
