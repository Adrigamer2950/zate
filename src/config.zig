listen_address: []const u8,

default_backend: []const u8,
backends: []const Backend,

status: zate.protocol.Packets.Status.Clientbound.StatusResponse,

pub const Backend = struct {
    name: []const u8,
    address: []const u8,

    pub fn toIpAddress(backend: Backend) !std.Io.net.IpAddress {
        return try std.Io.net.IpAddress.parseLiteral(backend.address);
    }
};

pub fn findBackend(config: Config, name: []const u8) ?Backend {
    for (config.backends) |backend| {
        if (std.mem.eql(u8, backend.name, name)) return backend;
    }

    return null;
}

pub const Config = @This();

const zate = @import("root.zig");

const std = @import("std");
