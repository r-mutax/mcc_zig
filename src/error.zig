const std = @import("std");
const stderr = std.io.getStdErr().writer();

pub fn error_at(comptime line: [:0] const u8, pos: u8, comptime fmt: []const u8, args: anytype) !void {
    _ = try stderr.print("{s}\n", .{ line });
    
    var p = pos;
    while(p > 0) : (p -= 1) {
        _ = try stderr.print("{c}", .{ ' ' });
    }
    _ = try stderr.print("{c}\n", .{ '^' });
    _ = try stderr.print(fmt, args);
}

test {
    error_at("abscdef", 3, "{s} is not c.\n", .{"cd"}) catch unreachable;
}