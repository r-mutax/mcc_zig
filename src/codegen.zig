const std = @import("std");
const parse = @import("./parse.zig");

const Parser = parse.Parser;
const Node = parse.Node;
const Function = parse.Function;
const Stmts = parse.Stmts;
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

        try self.genProgram();
        return;
    }

    fn genProgram(self: *Codegen) !void {
        var func_idx : usize = 0;
        while(func_idx < self.parser.functions.len) : (func_idx += 1){
            const func_name = self.parser.getFuncName(func_idx);
            try self.genFunction(func_name, func_idx);
        }
    }

    fn genFunction(self: *Codegen, name: [:0] const u8, idx : usize) !void {
        _ = try stdout.print("{s}:\n", .{ name });

        // prologue
        const memory = self.parser.getFuncMemory(idx);
        _ = try stdout.writeAll("  push rbp\n");
        _ = try stdout.writeAll("  mov rbp, rsp\n");
        _ = try stdout.print("  sub rsp, {}\n", .{ memory });

        const stmts = self.parser.getFunctionStmts(idx);
        for(stmts.items) | stmt | {
            try self.gen(stmt);
            _ = try stdout.writeAll("  pop rax\n");
        }
        
        _ = try stdout.writeAll("  mov rsp, rbp\n");
        _ = try stdout.writeAll("  pop rbp\n");
        _ = try stdout.writeAll("  ret\n");
        return;
    }

    fn gen_lval(self: *Codegen, node: usize) !void {
        if(self.parser.getNodeTag(node) != Node.Tag.nd_lvar){
            stderr.writeAll("error") catch unreachable;
            return;
        }

        _ = try stdout.writeAll("  mov rax, rbp\n");
        _ = try stdout.print("  sub rax, {}\n", .{self.parser.getNodeOffset(node)});
        _ = try stdout.writeAll("  push rax\n");
    }

    fn gen(self: *Codegen, node: usize) !void {

        switch(self.parser.getNodeTag(node)){
            Node.Tag.nd_num => {
                const val = self.parser.getNodeValue(node);
                _ = try stdout.print("  push {}\n", .{val});
                return;
            },
            Node.Tag.nd_lvar => {
                try self.gen_lval(node);
                _ = try stdout.writeAll("  pop rax\n");
                _ = try stdout.writeAll("  mov rax, [rax]\n");
                _ = try stdout.writeAll("  push rax\n");
                return;
            },
            Node.Tag.nd_assign => {
                try self.gen_lval(self.parser.getNodeLhs(node));
                try self.gen(self.parser.getNodeRhs(node));

                _ = try stdout.writeAll("  pop rdi\n");
                _ = try stdout.writeAll("  pop rax\n");
                _ = try stdout.writeAll("  mov [rax], rdi\n");
                _ = try stdout.writeAll("  push rdi\n");
                return;
            },
            else => {}
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
            Node.Tag.nd_equal=> {
                _ = try stdout.writeAll("  cmp rax, rdi\n");
                _ = try stdout.writeAll("  sete al\n");
                _ = try stdout.writeAll("  movzb rax, al\n");
            },
            Node.Tag.nd_not_equal=> {
                _ = try stdout.writeAll("  cmp rax, rdi\n");
                _ = try stdout.writeAll("  setne al\n");
                _ = try stdout.writeAll("  movzb rax, al\n");
            },
            Node.Tag.nd_gt => {
                _ = try stdout.writeAll("  cmp rax, rdi\n");
                _ = try stdout.writeAll("  setl al\n");
                _ = try stdout.writeAll("  movzb rax, al\n");
            },
            Node.Tag.nd_ge => {
                _ = try stdout.writeAll("  cmp rax, rdi\n");
                _ = try stdout.writeAll("  setle al\n");
                _ = try stdout.writeAll("  movzb rax, al\n");
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