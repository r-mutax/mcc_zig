const std = @import("std");
const Allocator = std.mem.Allocator;
const Tokenizer = @import("./tokenizer.zig");
const Parser = @import("./parse.zig").Parser;
const Ast = @This();
const scope = @import("scope.zig");
const ScopeManager = scope.ScopeManager;
const Ident = scope.Ident;

source: [:0] const u8,
tokens: TokenList.Slice,
nodes: NodeList.Slice,
extra_data: ExtraDataList.Slice,
funclist: FunctionList.Slice,
scopmng: ScopeManager,

pub const TokenList = std.MultiArrayList(struct {
    tag: Token.Tag,
    start: usize,
});

pub fn deinit(tree: *Ast, gpa: Allocator) void {
    tree.tokens.deinit(gpa);
    tree.nodes.deinit(gpa);
    gpa.free(tree.extra_data);
    tree.* = undefined;
}

pub fn parse(gpa: Allocator, source: [:0] const u8) Allocator.Error ! Ast {
    var tokens = Ast.TokenList{};
    defer tokens.deinit(gpa);

    var tokenizer = Tokenizer.init(source); 
    while(true){
        const token = tokenizer.next();
        try tokens.append(gpa, .{
                    .tag = token.tag,
                    .start = token.loc.start,
                });
        if(token.tag == Token.Tag.tk_eof){
            break;
        }
    }

    var parser = Parser.init(gpa, source);
    defer parser.nodes.deinit(gpa);

    parser.parse();

    return Ast{
        .source = source,
        .tokens = tokens.toOwnedSlice(),
        .nodes = parser.nodes.toOwnedSlice(),
        .extra_data = parser.extras.toOwnedSlice(),
        .funclist = parser.functions.toOwnedSlice(),
        .scopmng = parser.scopemng,
    };
}

pub fn getFuncName(self:*Ast, idx:usize) [] const u8 {
    return self.funclist.items(.name)[idx];
}

pub fn getFuncMemory(self: *Ast, idx: usize) u32 {
    return self.funclist.items(.memory)[idx];
}

pub fn getFuncBody(self: *Ast, idx: usize) usize {
    return self.funclist.items(.body)[idx];
}

pub fn getFundParams(self: *Ast, idx: usize) std.ArrayList(usize) {
    return self.funclist.items(.params)[idx];
}

pub fn getVariableOffset(self: *Ast, idx: usize) usize{
    return self.scopmng.getVariableOffset(idx);
}

pub fn getNodeTag(self:*Ast, node: usize) Node.Tag {
    return self.nodes.items(.tag)[node];
}

pub fn getNodeValue(self: *Ast, node: usize) u32 {
    return self.nodes.items(.val)[node];
}

pub fn getNodeLhs(self: *Ast, node: usize) usize {
    return self.nodes.items(.lhs)[node];
}

pub fn getNodeRhs(self: *Ast, node: usize) usize {
    return self.nodes.items(.rhs)[node];
}

pub fn getNodeOffset(self: *Ast, node: usize) u32 {
    const ident = self.nodes.items(.ident)[node];
    const offset = self.scopmng.getVariableOffset(ident);
    return offset;
}

pub fn getNodeMainToken(self: *Ast, node: usize) usize {
    return self.nodes.items(.main_token)[node];
}

pub fn getLine(self: *Ast, token: usize) [] const u8 {
    const start = self.tokens.items(.start)[token];
    var tokenizer = Tokenizer.init(self.source);

    const line = tokenizer.getLine(start);
    return line;
}

pub fn getTokenSlice(self: *Ast, token: usize) [] const u8 {
    const start = self.tokens.items(.start)[token];
    var tokenizer = Tokenizer.init(self.source);

    const slice = tokenizer.getSlice(start);
    return slice;
}

pub fn getExtraDataInitNode(self: *Ast, idx: usize) usize {
    return self.extra_data.items(.init)[idx];
}

pub fn getExtraDataCondNode(self: *Ast, idx: usize) usize {
    return self.extra_data.items(.cond)[idx];
}

pub fn getExtraDataIncNode(self: *Ast, idx: usize) usize {
    return self.extra_data.items(.inc)[idx];
}

pub fn getExtraDataBody(self: *Ast, idx: usize) Stmts {
    return self.extra_data.items(.body)[idx];
}

pub fn getNodeExtra(self: *Ast, node: usize) usize {
    return self.nodes.items(.data)[node];
}


pub const Node = struct {
    pub const Tag = enum {
        nd_add,
            // lhs + rhs
        nd_sub,
            // lhs - rhs
        nd_mul,
            // lhs * rhs
        nd_div,
            // lhs / rhs
        nd_num,
            // lhs
        nd_equal,
            // lhs == rhs
        nd_not_equal,
            // lhs != rhs
        nd_gt,
            // lhs < rhs
        nd_ge,
            // lhs <= rhs
        nd_assign,
            // lhs = rhs
        nd_lvar,
            // local variable
        nd_return,
            // return statement
        nd_if_simple,
            // if statement
        nd_if,
        nd_then_else,
            // if statement and then block and else block
        nd_while,
            // while statement
        nd_for,
            // for statement
        nd_block,
            // block statement
        nd_call_function_noargs,
            // function call
        nd_call_function_have_args,
            // function call with argument
        nd_bit_and,
            // bitand
        nd_bit_xor,
            // bit-xor
        nd_bit_or,
            // bit-or
        nd_logic_and,
            // logic and
        nd_logic_or,
            // logic or
        nd_cond_expr,
            // condition expression
        nd_address,
            // address
        nd_dreference,
            // pointer dereference
    };
    main_token: usize,
    lhs: usize = undefined, // NodeLists index
    rhs: usize = undefined, // NodeLists index
    val: u32 = 0,           // value of nodes(in nd_num)
    tag: Tag,
    ident: usize = undefined,
    data: usize = undefined,    // extra data index
};
pub const Function = struct {
    name: [] const u8,
    body: usize,
    memory: u32 = 0,
    params: std.ArrayList(usize) = undefined,
};

pub const ExtraData = struct {
    init: usize = undefined,
    cond: usize = undefined,
    inc: usize = undefined,
    body: Stmts = undefined,
};

pub const NodeList = std.MultiArrayList(Ast.Node);
pub const FunctionList = std.MultiArrayList(Function);
pub const ExtraDataList = std.MultiArrayList(ExtraData);
pub const Stmts = std.ArrayList(usize);
const Token = Tokenizer.Token;
