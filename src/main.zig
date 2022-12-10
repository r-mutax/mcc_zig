const std = @import("std");
const expect = std.testing.expect;
const dprint = std.debug.print;


pub fn main() !void {
    const stderr = std.io.getStdErr();
    const stdout = std.io.getStdOut().writer();

    const args = std.os.argv;
    if (args.len != 2) {
        _ = try stderr.write("[error] invalid argument num.\n");
    }

    _ = try stdout.writeAll(".intel_syntax noprefix\n");
    _ = try stdout.writeAll(".global main\n");
    _ = try stdout.writeAll("main:\n");
    _ = try stdout.print("  mov rax, {s}\n", .{args[1]});
    _ = try stdout.writeAll("  ret\n");
}
