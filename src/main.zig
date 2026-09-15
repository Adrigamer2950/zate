const log = std.log.scoped(.zate);

const loopback: std.Io.net.IpAddress = .{ .ip4 = .loopback(0) };
pub const default_destination = std.Io.net.IpAddress.parseLiteral("127.0.0.1:25565") catch unreachable;

pub fn main() !void {
    var arena: std.heap.ArenaAllocator = .init(std.heap.page_allocator);

    var io_impl = std.Io.Threaded.init(std.heap.page_allocator, .{});
    defer io_impl.deinit();

    const io = io_impl.io();

    const string_address = zate.config.listen_address;

    const address = try std.Io.net.IpAddress.parseLiteral(string_address);

    var server = address.listen(io, .{
        .reuse_address = true,
    }) catch |err| switch (err) {
        error.AddressInUse => util.fatal(
            "the address {f} is already in use; another instance of this server might be already running",
            .{address},
        ),
        else => |e| util.fatal("failed to listen at {f}: {t}", .{ address, e }),
    };
    defer server.deinit(io);

    var client_group: std.Io.Group = .init;
    defer client_group.cancel(io);

    log.info("listening on tcp://{s}", .{string_address});

    while (true) {
        var stream = server.accept(io) catch |err| switch (err) {
            error.Canceled => |e| return e,
            error.SystemResources,
            error.ProcessFdQuotaExceeded,
            error.SystemFdQuotaExceeded,
            => {
                try io.sleep(.fromSeconds(1), .awake);
                continue;
            },
            else => |e| {
                log.err("accept failed: {t}", .{e});
                continue;
            },
        };

        client_group.concurrent(io, handleConnection, .{ io, stream, &arena }) catch |err| switch (err) {
            error.ConcurrencyUnavailable => {
                stream.close(io);
                continue;
            },
        };
    }
}

fn handleConnection(io: std.Io, stream: std.Io.net.Stream, arena: *std.heap.ArenaAllocator) void {
    defer stream.close(io);
    var addr_buf: [32]u8 = undefined;
    const addr = std.fmt.bufPrint(&addr_buf, "{f}", .{stream.socket.address}) catch @panic("OOM");
    log.info("client connected from {s}", .{addr});

    var connection_arena = std.heap.ArenaAllocator.init(arena.child_allocator);
    var connection: net.Connection = .{
        .client_stream = stream,
        .alloc = connection_arena.allocator(),
    };
    defer connection.closeBackendStream(io);

    var io_group: std.Io.Group = .init;
    defer io_group.await(io) catch |err| util.fatal("io error: {t}", .{err});

    // Client -> Zate
    io_group.concurrent(io, net.receivePackets, .{ .serverbound, io, &connection, arena }) catch |err| switch (err) {
        error.ConcurrencyUnavailable => util.fatal("Concurrency unavailable", .{}),
    };

    // Zate <- Backend
    io_group.concurrent(io, net.receivePackets, .{ .clientbound, io, &connection, arena }) catch |err| switch (err) {
        error.ConcurrencyUnavailable => util.fatal("Concurrency unavailable", .{}),
    };
}

const net = zate.net;
const protocol = zate.protocol;
const util = zate.util;
const zate = @import("root.zig");

const std = @import("std");
