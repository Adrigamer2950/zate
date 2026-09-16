pub var state: enum(u8) {
    running,
    closing,
} = .running;

extern "kernel32" fn SetConsoleCtrlHandler(
    HandlerRoutine: ?*const fn (dwCtrlType: windows.DWORD) callconv(.winapi) windows.BOOL,
    Add: windows.BOOL,
) callconv(.winapi) windows.BOOL;

pub fn waitForShutdown(io: std.Io) void {
    switch (builtin.os.tag) {
        .windows => {
            _ = SetConsoleCtrlHandler(winSigHandler, windows.TRUE);
        },
        else => {
            const act = std.posix.Sigaction{
                .handler = .{ .handler = sigHandler },
                .mask = std.posix.sigemptyset(),
                .flags = 0,
            };
            std.posix.sigaction(std.posix.SIG.INT, &act, null);
        },
    }

    while (true) {
        if (state == .closing) break;
        io.sleep(.fromMilliseconds(10), .real) catch |err| switch (err) {
            error.Canceled => return,
        };
    }
}

const CTRL_C_EVENT: windows.DWORD = 0;
const CTRL_BREAK_EVENT: windows.DWORD = 1;

fn winSigHandler(ctrl_type: windows.DWORD) callconv(.winapi) windows.BOOL {
    if (ctrl_type == CTRL_C_EVENT or ctrl_type == CTRL_BREAK_EVENT) {
        state = .closing;
    }
    return windows.FALSE;
}

fn sigHandler(sig: std.os.linux.SIG) callconv(.c) void {
    _ = sig;
    state = .closing;
}

const windows = std.os.windows;

const builtin = @import("builtin");
const std = @import("std");
