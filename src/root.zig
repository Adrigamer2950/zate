pub const net = @import("net/root.zig");
pub const protocol = @import("protocol/root.zig");
pub const util = @import("util.zig");

const Config = @import("config.zig");
pub const config: Config = @import("config");

test {
    _ = net;
    _ = protocol;
}
