const std = @import("std");
const expect = std.testing.expect;
const dprint = std.debug.print;


pub fn main() !void {
    const stderr = std.io.getStdErr();
    const ostream = std.io.getStdOut();

    const args = std.os.argv;
    if (args.len != 2) {
        _ = try stderr.write("[error] invalid argument num.\n");
    }

    _ = try ostream.write(".intel_syntax noprefix\n");
    _ = try ostream.write(".global main\n");
    _ = try ostream.write("main:\n");
    _ = try ostream.write("  mov rax, 12\n");
    _ = try ostream.write("  ret\n");
}

test "simple test" {
    var list = std.ArrayList(i32).init(std.testing.allocator);
    defer list.deinit(); // try commenting this out and see if zig detects the memory leak!
    try list.append(42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}
