const log = std.log.scoped(.@"zate::net");

pub fn receivePackets(
    direction: protocol.PacketDirection,
    io: std.Io,
    connection: *net.Connection,
    arena: *std.heap.ArenaAllocator,
) !void {
    if (direction == .clientbound) {
        while (connection.backend_stream == null) {
            io.sleep(.fromMilliseconds(50), .real) catch {};
        }
    }

    var stream = if (direction == .serverbound) connection.client_stream else connection.backend_stream.?;
    var reader_buffer: [4096]u8 = undefined;
    var stream_reader = stream.reader(io, &reader_buffer);
    var reader: net.Reader = .{ .reader = &stream_reader.interface };

    receivePacketsLoop(direction, io, connection, &reader, arena) catch |err| switch (err) {
        error.EndOfStream => {
            log.info("{s} disconnected", .{if (direction == .serverbound) "client" else "backend"});

            if (direction == .serverbound) {
                connection.shutdownBackendRead();
            } else {
                connection.shutdownClientRead();
            }
        },
        error.ReadFailed => log.err("reader error: {t} (underlying: {?t})", .{ err, stream_reader.err }),
        error.WriteFailed => log.err("writer error: {t}", .{err}),
        error.ValueTooBig => log.err("invalid size. value introduced was too big", .{}),
        error.ConnectionRefused => log.err("backend refused connection", .{}),
        else => log.err("unknown error: {t}", .{err}),
    };
}

fn receivePacketsLoop(
    direction: protocol.PacketDirection,
    io: std.Io,
    connection: *net.Connection,
    reader: *net.Reader,
    arena: *std.heap.ArenaAllocator,
) !void {
    while (true) {
        var packet_arena = std.heap.ArenaAllocator.init(arena.child_allocator);
        defer packet_arena.deinit();

        try readPacket(direction, io, reader, packet_arena.allocator(), connection);
    }
}

/// Packet Format:
///
/// When compression is disabled (compression threshold is not defined or less than 0):
/// - Packet Length -> VarInt
/// - Packet ID -> VarInt
/// - Body -> Byte Array
///
/// When compression is enabled (compression threshold is defined and more or equal than 0):
/// - Packet Length -> VarInt
/// - Data Length -> VarInt -> Length of uncompressed data (Packet ID + Body).
///                            0 if data came uncompressed, which happens when
///                            data length didn't meet compression threshold
/// - Data:
/// - - Packet ID -> VarInt
/// - - Body -> Byte Array
pub fn readPacket(
    direction: protocol.PacketDirection,
    io: std.Io,
    reader: *net.Reader,
    alloc: std.mem.Allocator,
    connection: *net.Connection,
) !void {
    const packet_len = try reader.readVarInt(u32);
    const threshold = connection.compression_threshold;

    if (threshold == null) {
        const packet_id = try reader.readVarInt(u32);
        try protocol.dispatchPacket(direction, io, reader, connection, packet_len.value, packet_id);
        return;
    }

    const data_len = try reader.readVarInt(u32);

    const remaining_in_frame = packet_len.bytes_read - data_len.bytes_read;

    if (data_len.value == 0) {
        const packet_id = try reader.readVarInt(u32);
        try protocol.dispatchPacket(direction, io, reader, connection, @intCast(remaining_in_frame), packet_id);
        return;
    }

    const compressed_buf = try alloc.alloc(u8, remaining_in_frame);
    try reader.readSliceAll(compressed_buf);

    var compressed_reader: std.Io.Reader = .fixed(compressed_buf);

    var flate_window: [std.compress.flate.max_window_len]u8 = undefined;
    var decompress: std.compress.flate.Decompress = .init(&compressed_reader, .zlib, &flate_window);

    const decompressed_buf = try alloc.alloc(u8, data_len.value);
    try decompress.reader.readSliceAll(decompressed_buf);

    var raw_payload_reader: std.Io.Reader = .fixed(decompressed_buf);
    var payload_reader: net.Reader = .{ .reader = &raw_payload_reader };
    const packet_id = try payload_reader.readVarInt(u32);
    try protocol.dispatchPacket(direction, io, &payload_reader, connection, data_len.value, packet_id);
}

const net = @import("root.zig");
const protocol = zate.protocol;
const zate = @import("../root.zig");

const std = @import("std");
