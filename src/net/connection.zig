const log = std.log.scoped(.@"zate::net");

alloc: std.mem.Allocator,
client_stream: std.Io.net.Stream,
backend_stream: ?std.Io.net.Stream = null,
state: net.ConnectionState = .handshake,
protocol_version: protocol.ProtocolVersion = .none,
compression_threshold: ?i32 = null,

pub fn switchState(connection: *Connection, new_state: net.ConnectionState) void {
    log.debug("switching state to {t}", .{new_state});
    connection.state = new_state;
}

pub fn createBackendStream(connection: *Connection, io: std.Io) !void {
    const backend = zate.config.findBackend(zate.config.default_backend) orelse return error.BackendNotFound;
    const destination = try backend.toIpAddress();

    connection.backend_stream = try destination.connect(io, .{ .mode = .stream });
    log.debug("connected to backend", .{});
}

const linux = std.os.linux;

pub fn shutdownClientRead(connection: *Connection) void {
    _ = linux.shutdown(connection.client_stream.socket.handle, linux.SHUT.RD);
}

pub fn shutdownBackendRead(connection: *Connection) void {
    if (connection.backend_stream) |backend| {
        _ = linux.shutdown(backend.socket.handle, linux.SHUT.RD);
    }
}

pub fn closeBackendStream(connection: *Connection, io: std.Io) void {
    if (connection.backend_stream) |*backend| {
        backend.close(io);
        connection.backend_stream = null;
    }
}

pub const Connection = @This();

const net = @import("root.zig");
const protocol = zate.protocol;
const zate = @import("../root.zig");

const std = @import("std");
