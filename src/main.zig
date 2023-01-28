const std = @import("std");
const expect = std.testing.expect;
const dprint = std.debug.print;

const tokenizer_lib = @import("tokenizer.zig");
const Tokenizer = tokenizer_lib.Tokenizer;

pub fn main() !void {
    const stderr = std.io.getStdErr().writer();
    const stdout = std.io.getStdOut().writer();

    const args = std.os.argv;
    if (args.len != 2) {
        _ = try stderr.write("[error] invalid argument num.\n");
    }
    var src = args[1][0..countChars(args[1]) : 0];

    var tokenizer = Tokenizer.init(src);
    tokenizer.tokenize();

    _ = try stdout.writeAll(".intel_syntax noprefix\n");
    _ = try stdout.writeAll(".global main\n");
    _ = try stdout.writeAll("main:\n");

    _ = try stdout.print("  mov rax, {}\n", .{ try tokenizer.expect_number()});

    while(!tokenizer.is_eof()){
        if(tokenizer.consume('+')){
            _ = try stdout.print("  add rax, {}\n", .{try tokenizer.expect_number()});
            continue;
        }

        try tokenizer.expect('-');
        _ = try stdout.print("  sub rax, {}\n", .{ try tokenizer.expect_number()});
    }

    _ = try stdout.writeAll("  ret\n");


    // // here src startswith digits.
    // {
    //     const n = countDigits(src[0..]);
    //     const digits = src[0..(n)];
    //     _ = try stdout.print("  mov rax, {}\n", .{std.fmt.parseUnsigned(u32, digits, 10)});
    // }

    // var i : u32 = 0;
    // while(i < src.len) : (i += 1) {
    //     const c = src[i];
    //     switch(c){
    //         '+' => {
    //             i += 1;
    //             const n = countDigits(src[i..]);
    //             const digits = src[i..(i + n)];
    //             _ = try stdout.print("  add rax, {}\n", .{std.fmt.parseUnsigned(u32, digits, 10)});
    //         },
    //         '-' => {
    //             i += 1;
    //             const n = countDigits(src[i..]);
    //             const digits = src[i..(i + n)];
    //             _ = try stdout.print("  sub rax, {}\n", .{std.fmt.parseUnsigned(u32, digits, 10)});
    //         },
    //         else => {
    //             // unreachable;
    //         }
    //     }
    // }

    // _ = try stdout.print("  ret\n", .{});
}

fn countChars(chars: [*:0]u8) usize {
    var i: usize = 0;
    while(true){
        if(chars[i] == 0){
            return i;
        }
        i += 1;
    }
}

fn countDigits(s: []const u8) usize {
    var i: usize = 0;
    while(i < s.len) : (i += 1){
        const c = s[i];
        if(!std.ascii.isDigit(c)){
            break;
        }
    }
    return i;
}