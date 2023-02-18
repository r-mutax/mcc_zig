const std = @import("std");
const parse = @import("./parse.zig");

const Parser = parse.Parser;
const Node = parse.Node;
const stderr = std.io.getStdErr().writer();
const stdout = std.io.getStdOut().writer();
const Allocator = std.mem.Allocator;


pub const Codegen = struct {
    parser: Parser = undefined,

    pub fn init(gpa: Allocator, source: [:0]const u8) Codegen {
        var result = Codegen{};
        result.parser = Parser.init(gpa, source);

        return result;
    }

    pub fn codegen(self: *Codegen) usize {
        _ = self.parser.parse();

        // TODO: defer parser.deinit();

        _ = stdout.writeAll(".intel_syntax noprefix\n") catch unreachable;
        _ = stdout.writeAll(".global main\n") catch unreachable;
        _ = stdout.writeAll("main:\n") catch unreachable;

        const root = self.parser.root;
        self.gen(root);
        _ = stdout.writeAll("  pop rax\n") catch unreachable;
        _ = stdout.writeAll("  ret\n") catch unreachable;


        return root;
    }

    fn gen(self: *Codegen, node: usize) void {
        if(self.parser.getNodeTag(node) == Node.Tag.nd_num){
            const val = self.parser.getNodeValue(node);
            _ = stdout.print("  push {}\n", .{val}) catch unreachable;
            return;
        }

        self.gen(self.parser.getNodeLhs(node));
        self.gen(self.parser.getNodeRhs(node));
        _ = stdout.writeAll("  pop rdi\n") catch unreachable;
        _ = stdout.writeAll("  pop rax\n") catch unreachable;

        switch(self.parser.getNodeTag(node)){
            Node.Tag.nd_add => {
                _ = stdout.writeAll("  add rax, rdi\n") catch unreachable;
            },
            else => {

            }
        }
        _ = stdout.writeAll("  push rax\n") catch unreachable;
    }

};

test "codegen" {
    var codegen = Codegen.init(std.heap.page_allocator, "3+4");
    const root = codegen.codegen();
    try std.testing.expectEqual(root, 2);
}