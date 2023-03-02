const std = @import("std");
const expect = std.testing.expect;
const dprint = std.debug.print;

const tokenizer_lib = @import("tokenizer.zig");
const CodeGen = @import("codegen.zig");

pub fn main() !void {
    
    const stderr = std.io.getStdErr().writer();
    const args = std.os.argv;
    if (args.len != 2) {
        _ = try stderr.write("[error] invalid argument num.\n");
    }
    var src = args[1][0..countChars(args[1]) : 0];
    var codegen = CodeGen.Codegen.init(std.heap.page_allocator, src);
    try codegen.codegen();
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