const log = std.log.scoped(.@"zate::protocol");

pub const Packets = @import("packets/root.zig");

pub const Packet = struct {
    direction: PacketDirection,
    state: net.ConnectionState,
    id: u32,
    data: ?PacketData = null,

    const PacketData = struct {
        ptr: *const anyopaque,
        encodeFn: ?*const fn (ptr: *const anyopaque, writer: *net.Writer) anyerror!void,
        name: []const u8,

        pub fn encode(self: PacketData, writer: *net.Writer) !void {
            if (self.encodeFn) |f| try f(self.ptr, writer);
        }

        pub fn init(data: anytype) PacketData {
            const T = @TypeOf(data.*);
            const gen = struct {
                fn encode(ptr: *const anyopaque, writer: *net.Writer) anyerror!void {
                    const self: *const T = @ptrCast(@alignCast(ptr));
                    try self.encode(writer);
                }
            };

            return .{
                .ptr = data,
                .encodeFn = if (@hasDecl(T, "encode")) gen.encode else null,
                .name = if (@hasDecl(T, "packet_name")) T.packet_name else "unknown",
            };
        }
    };
};

pub const PacketDirection = enum(u1) {
    serverbound, // Client -> Server
    clientbound, // Server -> Client
};

pub fn dispatchPacket(
    direction: PacketDirection,
    io: std.Io,
    reader: *net.Reader,
    connection: *net.Connection,
    packet_len: u32,
    raw_packet_id: protocol.VarInt(u32),
) !void {
    const remaining = packet_len - raw_packet_id.bytes_read;

    inline for (@typeInfo(protocol.Packets).@"struct".decls) |state_decl| {
        var state_name_buf: [32]u8 = undefined;
        const state_name = std.ascii.lowerString(&state_name_buf, state_decl.name);

        if (std.mem.eql(u8, state_name, @tagName(connection.state))) {
            const State = @field(protocol.Packets, state_decl.name);

            inline for (@typeInfo(State).@"struct".decls) |direction_decl| {
                var direction_name_buf: [32]u8 = undefined;
                const direction_name = std.ascii.lowerString(&direction_name_buf, direction_decl.name);

                if (std.mem.eql(u8, direction_name, @tagName(direction))) {
                    const Direction = @field(State, direction_decl.name);

                    inline for (@typeInfo(Direction).@"struct".decls) |packet_decl| {
                        const PacketInfo = @field(Direction, packet_decl.name);

                        if (!@hasDecl(PacketInfo, "decode")) continue;

                        const packet_name = PacketInfo.packet_name;
                        const packet_id = PacketInfo.packet_id;

                        if (packet_id == raw_packet_id.value) {
                            log.debug("received: state={t} packet_name={s} packet_len={d}", .{ connection.state, packet_name, remaining });

                            var limited_buffer: [2048]u8 = undefined;
                            var limited_reader = reader.reader.limited(.limited(remaining), &limited_buffer);
                            var limited: net.Reader = .{ .reader = &limited_reader.interface };

                            const packet = try callDecode(PacketInfo, &limited, connection.alloc);
                            defer {
                                if (@hasDecl(PacketInfo, "deinit")) packet.deinit();
                            }

                            if (@hasDecl(PacketInfo, "handle")) {
                                try packet.handle(connection, io);
                            } else {
                                try protocol.sendPacket(io, connection, .{
                                    .direction = direction,
                                    .state = connection.state,
                                    .id = packet_id,
                                    .data = .init(&packet),
                                });
                            }

                            limited.discardAll(remaining) catch |err| switch (err) {
                                error.EndOfStream => {},
                                else => |e| return e,
                            };

                            return;
                        }
                    }
                }
            }
        }
    }

    // Packet wasn't handled so we just forward it to its destination

    const body_buf = try connection.alloc.alloc(u8, 3 + remaining); // Giving 3 bytes for packet_id
    var raw_body_writer: std.Io.Writer = .fixed(body_buf);
    var body_writer: net.Writer = .{ .writer = &raw_body_writer };

    try body_writer.writeVarInt(u32, raw_packet_id.value);
    if (remaining > 0) {
        const payload_buf = try connection.alloc.alloc(u8, remaining);
        try reader.readSliceAll(payload_buf);
        try body_writer.writeAll(payload_buf);
    }

    const dest_direction: PacketDirection = if (direction == .serverbound) .serverbound else .clientbound;
    try writeFramedBody(io, connection, dest_direction, body_writer.buffered(), connection.alloc);

    log.warn("unhandled packet: origin={s} state={t} direction={t} id={d}", .{
        if (direction == .serverbound) "client" else "backend",
        connection.state,
        direction,
        raw_packet_id.value,
    });
}

fn ReturnType(comptime T: type, comptime name: []const u8) type {
    inline for (@typeInfo(T).@"struct".decls) |func_decl| {
        if (std.mem.eql(u8, func_decl.name, name)) {
            const Fn = @TypeOf(@field(T, func_decl.name));
            const fn_info = @typeInfo(Fn).@"fn";
            return fn_info.return_type.?;
        }
    }
    @compileError("function " ++ name ++ " not found on " ++ @typeName(T));
}

fn callDecode(
    comptime T: type,
    reader: *net.Reader,
    alloc: std.mem.Allocator,
) ReturnType(T, "decode") {
    inline for (@typeInfo(T).@"struct".decls) |func_decl| {
        if (comptime std.mem.eql(u8, func_decl.name, "decode")) {
            const Fn = @TypeOf(@field(T, func_decl.name));

            switch (@typeInfo(Fn)) {
                .@"fn" => {
                    const Args = std.meta.ArgsTuple(Fn);
                    var args: Args = undefined;

                    inline for (&args, @typeInfo(Args).@"struct".fields) |*arg, arg_info| {
                        const ArgType = arg_info.type;

                        if (ArgType == *net.Reader) {
                            arg.* = reader;
                            continue;
                        }

                        if (ArgType == *std.Io.Reader) {
                            arg.* = reader.reader;
                            continue;
                        }

                        if (ArgType == std.mem.Allocator) {
                            arg.* = alloc;
                            continue;
                        }

                        @compileError(func_decl.name ++ ": invalid argument type: " ++ @typeName(ArgType));
                    }

                    return @call(.auto, @field(T, func_decl.name), args);
                },
                else => {},
            }
        }
    }

    unreachable;
}

pub fn sendPacket(
    io: std.Io,
    connection: *net.Connection,
    packet: Packet,
) !void {
    log.debug("sending to {s}: state={t} packet_name={s}", .{
        if (packet.direction == .clientbound) "client" else "backend",
        packet.state,
        if (packet.data) |data| data.name else "none",
    });

    var body_buf: [4096]u8 = undefined;
    var raw_body_writer: std.Io.Writer = .fixed(&body_buf);
    var body_writer: net.Writer = .{ .writer = &raw_body_writer };

    try body_writer.writeVarInt(u32, packet.id);
    if (packet.data) |data| {
        try data.encode(&body_writer);
    }

    try writeFramedBody(io, connection, packet.direction, body_writer.buffered(), connection.alloc);
}

// Refer to src/net/receiver.zig for documentation on how is a Packet structured
fn writeFramedBody(
    io: std.Io,
    connection: *net.Connection,
    direction: PacketDirection,
    body: []const u8,
    alloc: std.mem.Allocator,
) !void {
    var stream = if (direction == .clientbound)
        connection.client_stream
    else
        connection.backend_stream orelse return error.BackendOffline;

    var writer_buffer: [4096]u8 = undefined;
    var stream_writer = stream.writer(io, &writer_buffer);
    var writer: net.Writer = .{ .writer = &stream_writer.interface };

    if (connection.compression_threshold) |threshold| {
        if (body.len >= threshold) {
            const compressed_buf = try alloc.alloc(u8, body.len + 64);
            var compressed_writer: std.Io.Writer = .fixed(compressed_buf);

            var deflate_window: [std.compress.flate.max_window_len]u8 = undefined;
            var compress: std.compress.flate.Compress = try .init(&compressed_writer, &deflate_window, .zlib, .default);
            try compress.writer.writeAll(body);
            try compress.finish();

            const compressed = compressed_writer.buffered();

            const frame_buf = try alloc.alloc(u8, 5 + compressed.len);
            var raw_frame_writer: std.Io.Writer = .fixed(frame_buf);
            var frame_writer: net.Writer = .{ .writer = &raw_frame_writer };

            try frame_writer.writeVarInt(u32, @intCast(body.len));
            try frame_writer.writeAll(compressed);

            const frame = frame_writer.buffered();
            try writer.writeVarInt(u32, @intCast(frame.len));
            try writer.writeAll(frame);
        } else {
            const frame_buf = try alloc.alloc(u8, 5 + body.len);
            var raw_frame_writer: std.Io.Writer = .fixed(frame_buf);
            var frame_writer: net.Writer = .{ .writer = &raw_frame_writer };

            try frame_writer.writeVarInt(u32, 0);
            try frame_writer.writeAll(body);

            const frame = frame_writer.buffered();
            try writer.writeVarInt(u32, @intCast(frame.len));
            try writer.writeAll(frame);
        }
    } else {
        try writer.writeVarInt(u32, @intCast(body.len));
        try writer.writeAll(body);
    }

    try writer.flush();
}

const net = zate.net;
const protocol = @import("root.zig");
const zate = @import("../root.zig");

const std = @import("std");
