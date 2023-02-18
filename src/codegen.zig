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

    pub fn codegen(self: *Codegen) !void {
        _ = self.parser.parse();

        // TODO: defer parser.deinit();

        _ = try stdout.writeAll(".intel_syntax noprefix\n");
        _ = try stdout.writeAll(".global main\n");
        _ = try stdout.writeAll("main:\n");

        const root = self.parser.root;
        try self.gen(root);
        _ = try stdout.writeAll("  pop rax\n");
        _ = try stdout.writeAll("  ret\n");

        return;
    }

    fn gen(self: *Codegen, node: usize) !void {
        if(self.parser.getNodeTag(node) == Node.Tag.nd_num){
            const val = self.parser.getNodeValue(node);
            _ = try stdout.print("  push {}\n", .{val});
            return;
        }

        try self.gen(self.parser.getNodeLhs(node));
        try self.gen(self.parser.getNodeRhs(node));
        _ = try stdout.writeAll("  pop rdi\n") ;
        _ = try stdout.writeAll("  pop rax\n") ;

        switch(self.parser.getNodeTag(node)){
            Node.Tag.nd_add => {
                _ = try stdout.writeAll("  add rax, rdi\n");
            },
            Node.Tag.nd_sub => {
                _ = try stdout.writeAll("  sub rax, rdi\n");
            },
            Node.Tag.nd_mul => {
                _ = try stdout.writeAll("  imul rax, rdi\n");
            },
            Node.Tag.nd_div => {
                _ = try stdout.writeAll("  cqo\n");
                _ = try stdout.writeAll("  idiv rdi\n");
            },
            else => {

            }
        }
        try stdout.writeAll("  push rax\n");
    }

};

test "codegen" {
    var codegen = Codegen.init(std.heap.page_allocator, "3+4");
    const root = codegen.codegen();
    try std.testing.expectEqual(root, 2);
}