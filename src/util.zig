const log = std.log.scoped(.zate);

pub fn stringify(buf: []u8, payload: anytype, options: std.json.Stringify.Options) ![]u8 {
    return try std.fmt.bufPrint(buf, "{f}", .{std.json.fmt(payload, options)});
}

pub fn fatal(comptime fmt: []const u8, args: anytype) noreturn {
    log.err(fmt, args);
    std.process.exit(1);
}

const std = @import("std");
