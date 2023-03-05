const std = @import("std");
const parse = @import("parse.zig");
const Ast = @import("AST.zig");

const Parser = parse.Parser;
const Node = Ast.Node;
const Function = Ast.Function;
const Stmts = Ast.Stmts;
const stderr = std.io.getStdErr().writer();
const stdout = std.io.getStdOut().writer();
const Allocator = std.mem.Allocator;

pub const Codegen = struct {
    parser: Parser = undefined,
    ast: Ast = undefined,
    label_no: u32 = 0,
    source: [:0]const u8 = undefined,

    const argreg64 = [_][:0]const u8{ "rdi", "rsi", "rdx", "rcx", "r8", "r9" };
    pub fn init(gpa: Allocator, source: [:0]const u8) Codegen {
        var result = Codegen{};
        result.parser = Parser.init(gpa, source);
        result.source = source;

        return result;
    }

    pub fn codegen(self: *Codegen) !void {
        _ = self.parser.parse();

        self.ast = try Ast.parse(std.heap.page_allocator, self.source);

        // TODO: defer parser.deinit();

        _ = try stdout.writeAll(".intel_syntax noprefix\n");
        _ = try stdout.writeAll(".global main\n");

        try self.genProgram();
        return;
    }

    fn genProgram(self: *Codegen) !void {
        var func_idx: usize = 0;
        while (func_idx < self.ast.funclist.len) : (func_idx += 1) {
            try self.genFunction(func_idx);
        }
    }

    fn genFunction(self: *Codegen, idx: usize) !void {
        const func_name = self.ast.getFuncName(idx);
        _ = try stdout.print("{s}:\n", .{func_name});

        // prologue
        const memory = self.ast.getFuncMemory(idx);
        _ = try stdout.writeAll("  push rbp\n");
        _ = try stdout.writeAll("  mov rbp, rsp\n");

        // alloc local variable area.
        _ = try stdout.print("  sub rsp, {}\n", .{((memory + 15) / 16) * 16});

        // move arguments register to stack.
        var params = self.ast.getFundParams(idx);
        for (params.items, 0..) |p, i| {
            const offset = self.ast.getVariableOffset(p);
            _ = try stdout.print("  mov [rbp - {}], {s}\n", .{ offset, argreg64[i] });
        }

        try self.gen_stmt(self.ast.getFuncBody(idx));

        _ = try stdout.writeAll("  mov rsp, rbp\n");
        _ = try stdout.writeAll("  pop rbp\n");
        _ = try stdout.writeAll("  ret\n");
        return;
    }

    fn gen_lval(self: *Codegen, node: usize) !void {
        if (self.ast.getNodeTag(node) != Node.Tag.nd_lvar) {
            stderr.writeAll("error") catch unreachable;
            return;
        }

        _ = try stdout.writeAll("  mov rax, rbp\n");
        _ = try stdout.print("  sub rax, {}\n", .{self.ast.getNodeOffset(node)});
        _ = try stdout.writeAll("  push rax\n");
    }

    fn getLabelNo(self: *Codegen) u32 {
        const result = self.label_no;
        self.label_no += 1;
        return result;
    }

    fn gen_stmt(self: *Codegen, node: usize) !void {
        //const token = self.ast.getNodeMainToken(node);
        //const line = self.ast.getLine(token);
        //_ = try stdout.print("# {s}\n", .{line});
        // const tk = self.parser.getTokenSlice(token);
        // const tk2 = self.parser.getTokenSlice(token+1);
        // _ = try stdout.print("# {s}{s}\n", .{tk, tk2});
        switch (self.ast.getNodeTag(node)) {
            Node.Tag.nd_return => {
                try self.gen_expr(self.ast.getNodeLhs(node));
                _ = try stdout.writeAll("  pop rax\n");
                _ = try stdout.writeAll("  mov rsp, rbp\n");
                _ = try stdout.writeAll("  pop rbp\n");
                _ = try stdout.writeAll("  ret\n");
                return;
            },
            Node.Tag.nd_if_simple => {
                const no = self.getLabelNo();
                try self.gen_expr(self.ast.getNodeLhs(node));
                _ = try stdout.writeAll("  pop rax\n");
                _ = try stdout.writeAll("  cmp rax, 0\n");
                _ = try stdout.writeAll("  sete al\n");
                _ = try stdout.print("  je .Lend{}\n", .{no});
                try self.gen_stmt(self.ast.getNodeRhs(node));
                _ = try stdout.print(".Lend{}:\n", .{no});
                return;
            },
            Node.Tag.nd_if => {
                const no = self.getLabelNo();
                const then_else = self.ast.getNodeRhs(node);
                try self.gen_expr(self.ast.getNodeLhs(node));
                _ = try stdout.writeAll("  pop rax\n");
                _ = try stdout.writeAll("  cmp rax, 0\n");
                _ = try stdout.writeAll("  sete al\n");
                _ = try stdout.print("  je .Lelse{}\n", .{no});

                // then block
                try self.gen_stmt(self.ast.getNodeLhs(then_else));
                _ = try stdout.print("  jmp .Lend{}\n", .{no});

                // else block
                _ = try stdout.print(".Lelse{}:\n", .{no});
                try self.gen_stmt(self.ast.getNodeRhs(then_else));

                _ = try stdout.print(".Lend{}:\n", .{no});
            },
            Node.Tag.nd_while => {
                const no = self.getLabelNo();
                _ = try stdout.print(".Lbegin{}:\n", .{no});
                try self.gen_expr(self.ast.getNodeLhs(node));
                _ = try stdout.writeAll("  pop rax\n");
                _ = try stdout.writeAll("  cmp rax, 0\n");
                _ = try stdout.writeAll("  sete al\n");
                _ = try stdout.print("  je .Lend{}\n", .{no});

                // body
                try self.gen_stmt(self.ast.getNodeRhs(node));
                _ = try stdout.print("  jmp .Lbegin{}\n", .{no});

                _ = try stdout.print(".Lend{}:\n", .{no});
            },
            Node.Tag.nd_for => {
                const no = self.getLabelNo();
                const extra = self.ast.getNodeExtra(node);

                // initialize
                try self.gen_stmt(self.ast.getExtraDataInitNode(extra));

                // condition check
                _ = try stdout.print(".Lstart{}:\n", .{no});
                try self.gen_stmt(self.ast.getExtraDataCondNode(extra));
                _ = try stdout.writeAll("  pop rax\n");
                _ = try stdout.writeAll("  cmp rax, 0\n");
                _ = try stdout.writeAll("  sete al\n");
                _ = try stdout.print("  je .Lend{}\n", .{no});

                try self.gen_stmt(self.ast.getNodeLhs(node));
                try self.gen_stmt(self.ast.getExtraDataIncNode(extra));
                _ = try stdout.print("  jmp .Lstart{}\n", .{no});
                _ = try stdout.print(".Lend{}:\n", .{no});
            },
            Node.Tag.nd_block => {
                const extra = self.ast.getNodeExtra(node);
                const stmts = self.ast.getExtraDataBody(extra);

                for (stmts.items) |stmt| {
                    try self.gen_stmt(stmt);
                }
            },
            else => try self.gen_expr(node),
        }
    }

    fn gen_expr(self: *Codegen, node: usize) !void {
        switch (self.ast.getNodeTag(node)) {
            Node.Tag.nd_num => {
                const val = self.ast.getNodeValue(node);
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
                try self.gen_lval(self.ast.getNodeLhs(node));
                try self.gen_expr(self.ast.getNodeRhs(node));

                _ = try stdout.writeAll("  pop rdi\n");
                _ = try stdout.writeAll("  pop rax\n");
                _ = try stdout.writeAll("  mov [rax], rdi\n");
                _ = try stdout.writeAll("  push rdi\n");
                return;
            },
            Node.Tag.nd_call_function_noargs => {
                const token = self.ast.getNodeMainToken(node);
                const func_name = self.ast.getTokenSlice(token);

                _ = try stdout.print("  call {s}\n", .{func_name});
                _ = try stdout.writeAll("  push rax\n");
                return;
            },
            Node.Tag.nd_call_function_have_args => {
                const token = self.ast.getNodeMainToken(node);
                const func_name = self.ast.getTokenSlice(token);

                const extra = self.ast.getNodeExtra(node);
                const args = self.ast.getExtraDataBody(extra);
                for (args.items) |arg| {
                    try self.gen_expr(arg);
                    //_ = try stdout.writeAll("  pop rax\n");
                }

                for (args.items, 0..) |_, idx| {
                    _ = try stdout.print("  pop {s}\n", .{argreg64[args.items.len - 1 - idx]});
                }

                _ = try stdout.print("  call {s}\n", .{func_name});
                _ = try stdout.writeAll("  push rax\n");
                return;
            },
            Node.Tag.nd_logic_and => {
                const no = self.getLabelNo();

                // eval lhs
                try self.gen_expr(self.ast.getNodeLhs(node));
                _ = try stdout.writeAll("  pop rax\n");
                _ = try stdout.writeAll("  cmp rax, 0\n");
                _ = try stdout.print("  je .Lfalse{}\n", .{no});

                // eval rhs
                try self.gen_expr(self.ast.getNodeRhs(node));
                _ = try stdout.writeAll("  pop rax\n");
                _ = try stdout.writeAll("  cmp rax, 0\n");
                _ = try stdout.print("  je .Lfalse{}\n", .{no});

                // write
                _ = try stdout.writeAll("  mov rax, 1\n");
                _ = try stdout.print("  jmp .Lend{}\n", .{no});
                _ = try stdout.print(".Lfalse{}:\n", .{no});
                _ = try stdout.writeAll("  mov rax, 0\n");
                _ = try stdout.print(".Lend{}:\n", .{no});

                _ = try stdout.writeAll("  push rax\n");
                return;
            },
            Node.Tag.nd_logic_or => {
                const no = self.getLabelNo();

                // eval lhs
                try self.gen_expr(self.ast.getNodeLhs(node));
                _ = try stdout.writeAll("  pop rax\n");
                _ = try stdout.writeAll("  cmp rax, 0\n");
                _ = try stdout.print("  jne .Ltrue{}\n", .{no});
                // eval rhs
                try self.gen_expr(self.ast.getNodeRhs(node));
                _ = try stdout.writeAll("  pop rax\n");
                _ = try stdout.writeAll("  cmp rax, 0\n");
                _ = try stdout.print("  jne .Ltrue{}\n", .{no});

                _ = try stdout.writeAll("  mov rax, 0\n");
                _ = try stdout.print("  jmp .Lend{}\n", .{no});
                _ = try stdout.print(".Ltrue{}:\n", .{no});
                _ = try stdout.writeAll("  mov rax, 1\n");
                _ = try stdout.print(".Lend{}:\n", .{no});

                _ = try stdout.writeAll("  push rax\n");
                return;
            },
            .nd_cond_expr => {
                const no = self.getLabelNo();
                const extra = self.ast.getNodeExtra(node);

                try self.gen_expr(self.ast.getNodeLhs(node));
                _ = try stdout.writeAll("  pop rax\n");
                _ = try stdout.writeAll("  cmp rax, 0\n");
                _ = try stdout.print("  je .Lfalse{}\n", .{no});

                try self.gen_expr(self.ast.getNodeLhs(extra));
                _ = try stdout.writeAll("  pop rax\n");
                _ = try stdout.print("  jmp .Lend{}\n", .{no});
                _ = try stdout.print(".Lfalse{}:\n", .{no});
                try self.gen_expr(self.ast.getNodeRhs(extra));
                _ = try stdout.writeAll("  pop rax\n");
                _ = try stdout.print(".Lend{}:\n", .{no});

                _ = try stdout.writeAll("  push rax\n");
                return;
            },
            .nd_address => {
                try self.gen_lval(self.ast.getNodeLhs(node));
                return;
            },
            .nd_dreference => {
                try self.gen_expr(self.ast.getNodeLhs(node));
                _ = try stdout.writeAll("  pop rax\n");
                _ = try stdout.writeAll("  mov rax, [rax]\n");
                _ = try stdout.writeAll("  push rax\n");
                return;
            },
            else => {},
        }

        try self.gen_expr(self.ast.getNodeLhs(node));
        try self.gen_expr(self.ast.getNodeRhs(node));
        _ = try stdout.writeAll("  pop rdi\n");
        _ = try stdout.writeAll("  pop rax\n");

        switch (self.ast.getNodeTag(node)) {
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
            Node.Tag.nd_equal => {
                _ = try stdout.writeAll("  cmp rax, rdi\n");
                _ = try stdout.writeAll("  sete al\n");
                _ = try stdout.writeAll("  movzb rax, al\n");
            },
            Node.Tag.nd_not_equal => {
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
            Node.Tag.nd_bit_and => {
                _ = try stdout.writeAll("  and rax, rdi\n");
            },
            Node.Tag.nd_bit_xor => {
                _ = try stdout.writeAll("  xor rax, rdi\n");
            },
            Node.Tag.nd_bit_or => {
                _ = try stdout.writeAll("  or rax, rdi\n");
            },
            else => {},
        }
        try stdout.writeAll("  push rax\n");
    }
};

test "codegen" {
    var codegen = Codegen.init(std.heap.page_allocator, "3+4");
    const root = codegen.codegen();
    try std.testing.expectEqual(root, 2);
}
