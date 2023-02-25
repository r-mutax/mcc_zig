const std = @import("std");
const Allocator = std.mem.Allocator;
const stdout = std.io.getStdOut().writer();
const stderr = std.io.getStdErr().writer();

const Tokenizer = @import("Tokenizer.zig");
const Token = Tokenizer.Token;
pub const TokenList = std.MultiArrayList(struct {
    tag: Token.Tag,
    start: usize,
});
const TokenError = Tokenizer.TokenError;

pub const Stmts = std.ArrayList(usize);

pub const ExtraData = struct {
    init: usize = undefined,
    cond: usize = undefined,
    inc: usize = undefined,
    body: Stmts = undefined,
};
pub const ExtraDataList = std.MultiArrayList(ExtraData);

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
        nd_call_function,
            // function call
    };
    main_token: usize,
    lhs: usize = undefined, // NodeLists index
    rhs: usize = undefined, // NodeLists index
    val: u32 = 0,           // value of nodes(in nd_num)
    tag: Tag,
    ident: usize = undefined,
    data: usize = undefined,    // extra data index
};

pub const Ident = struct {
    const Tag = enum {
        local_variable,
        function,
    };
    size: u32 = undefined,
    tag: Tag,
    offset: u32 = undefined,
};
pub const IdentList = std.MultiArrayList(Ident);

pub const Scope = struct {
    dict: std.StringHashMap(usize),
    level: u8,
    parent: ?usize,
    offset: u32 = 0,
};
pub const ScopeList = std.MultiArrayList(Scope);


pub const Nodes = std.MultiArrayList(Node);

pub const Function = struct {
    name: [] const u8,
    body: usize,
    memory: u32 = 0,
};
pub const FunctionList = std.MultiArrayList(Function);

pub const Parser = struct {
    gpa: Allocator,
    source: [:0] const u8,
    tokens: TokenList = undefined,
    tkidx: usize,           // index of TokenList.
    root: usize,            // NodeList index of rootNode.
    nodes: Nodes = undefined,
    functions: FunctionList = undefined,
    scopes: ScopeList = undefined,
    scidx: usize,
    idents: IdentList = undefined,
    memory: u32 = 0,
    //stmts: Stmts = undefined,
    extras: ExtraDataList = undefined,

    pub fn init(gpa: Allocator, source: [:0]const u8) Parser {
        return Parser {
            .gpa = gpa,
            .source = source,
            .tkidx = 0,
            .root = 0,
            .scidx = 0,
        };
    }

    pub fn parse(self: *Parser) void {

        // トークンリストを作る
        self.tokens = TokenList{};
        self.nodes = Nodes{};
        self.functions = FunctionList{};
        self.scopes = ScopeList{};
        self.idents = IdentList{};
        self.extras = ExtraDataList{};

        var tokenizer = Tokenizer.Tokenizer.init(self.source);   
        while(true) {
            const token = tokenizer.next();
            self.tokens.append(self.gpa, 
                .{
                    .tag = token.tag,
                    .start = token.loc.start,
                }
            ) catch unreachable;
            if (token.tag == Token.Tag.tk_eof){
                break;
            }
        }

        self.genGlobalScope();
        self.scopes.items(.parent)[self.scidx] = null;

        // パースする
        self.parseProgram() catch unreachable;
        return;
    }

    pub fn genGlobalScope(self: *Parser) void {
        self.scopes.append(self.gpa, .{
            .dict = std.StringHashMap(usize).init(self.gpa),
            .level = 0,
            .parent = null,
        }) catch unreachable;
        self.scidx = 0;
        return;
    }
    // pub fn genScope(self: *Parser) void {
    //     const idx = self.scopes.len;
    //     self.scopes.append(self.gpa, .{
    //         .dict = std.StringHashMap(usize).init(self.gpa),
    //         .level = self.scopes.items(.level)[self.scidx],
    //         .parent = self.scidx,
    //     }) catch unreachable;
    //     self.scidx = idx;
    //     return;
    // }

    pub fn findIdent(self: *Parser, name: [] const u8) ?usize {       
        var idx = self.scidx;
        while(true){
            var dict = self.scopes.items(.dict)[idx];
            const ident = dict.get(name);
            if(ident) |i|{
                return i;
            }

            var parent = self.scopes.items(.parent)[idx];
            if(parent == null){
                return null;
            }

            idx = parent.?;
        }
    }

    pub fn appendIdent(self: *Parser, name: [] const u8, ident: Ident) usize {
        self.memory += ident.size;
        const ident_idx = self.idents.len;
        self.idents.append(self.gpa, ident) catch unreachable;

        var dict = self.scopes.items(.dict)[self.scidx];

        dict.put(name, ident_idx) catch unreachable;
        self.scopes.items(.dict)[self.scidx] = dict;
        return ident_idx;
    }

    pub fn getFuncName(self:*Parser, idx:usize) [] const u8 {
        return self.functions.items(.name)[idx];
    }

    pub fn getFuncMemory(self: *Parser, idx: usize) u32 {
        return self.functions.items(.memory)[idx];
    }

    pub fn getFuncBody(self: *Parser, idx: usize) usize {
        return self.functions.items(.body)[idx];
    }

    pub fn getNodeTag(self:*Parser, node: usize) Node.Tag {
        return self.nodes.items(.tag)[node];
    }

    pub fn getNodeValue(self: *Parser, node: usize) u32 {
        return self.nodes.items(.val)[node];
    }

    pub fn getNodeLhs(self: *Parser, node: usize) usize {
        return self.nodes.items(.lhs)[node];
    }

    pub fn getNodeRhs(self: *Parser, node: usize) usize {
        return self.nodes.items(.rhs)[node];
    }

    pub fn getNodeOffset(self: *Parser, node: usize) u32 {
        const ident = self.nodes.items(.ident)[node];
        const offset = self.idents.items(.offset)[ident];
        return offset;
    }

    pub fn getNodeMainToken(self: *Parser, node: usize) usize {
        return self.nodes.items(.main_token)[node];
    }

    fn addNode(self:*Parser, node: Node) usize {
        const idx = self.nodes.len;
        self.nodes.append(self.gpa, node) catch unreachable;
        return idx;
    }

    fn addNodeImm(self:*Parser, val: u32) usize {
        const idx = self.nodes.len;
        const node = Node {
            .tag = .nd_num,
            .val = val,
            .main_token = 0,
        };
        self.nodes.append(self.gpa, node) catch unreachable;
        return idx;
    }

    fn addExtraData(self: *Parser, extra: ExtraData) usize {
        const idx = self.extras.len;
        self.extras.append(self.gpa, extra) catch unreachable;
        return idx;
    }

    pub fn getExtraDataInitNode(self: *Parser, idx: usize) usize {
        return self.extras.items(.init)[idx];
    }

    pub fn getExtraDataCondNode(self: *Parser, idx: usize) usize {
        return self.extras.items(.cond)[idx];
    }

    pub fn getExtraDataIncNode(self: *Parser, idx: usize) usize {
        return self.extras.items(.inc)[idx];
    }

    pub fn getExtraDataBody(self: *Parser, idx: usize) Stmts {
        return self.extras.items(.body)[idx];
    }

    pub fn getNodeExtra(self: *Parser, node: usize) usize {
        return self.nodes.items(.data)[node];
    }

    fn nextToken(self: *Parser) usize {
        const result = self.tkidx;
        self.tkidx += 1;
        return result;
    }

    fn currentTokenTag(self: *Parser) Token.Tag {
        return self.tokens.items(.tag)[self.tkidx];
    }

    fn expectToken(self: *Parser, tag: Token.Tag) !void {
        if(self.currentTokenTag() != tag){
            return TokenError.UnexpectedToken;
        }
        _ = self.nextToken();
        return;
    }

    fn getCurrentTokenSlice(self: *Parser) [] const u8 {
        return self.getTokenSlice(self.tkidx);
    }

    pub fn getTokenSlice(self: *Parser, token: usize) [] const u8 {
        const start = self.tokens.items(.start)[token];
        var tokenizer = Tokenizer.Tokenizer.init(self.source);

        const slice = tokenizer.getSlice(start);
        return slice;
    }

    pub fn getStmtNode(self: *Parser, node: usize, stmt: usize) usize {
        const data = self.nodes.items(.data)[node];
        const body = self.extras.items(.body)[data];
        return body.items[stmt];
    }

    // program = function*
    // function = ident '()' compound_stmt
    // compound_stmt = '{' stmt* '}'
    // stmt = expr ';' 
    //          | 'return' expr ';'
    //          | 'if(' expr ')' stmt ('else' stmt)?
    //          | 'while(' expr ')' stmt
    //          | 'for(' expr ';' expr ';' expr ')' stmt
    //          | compound_stmt
    // expr = assign
    // assign = equality ('=' assign)?
    // equality = relational ( '==' relational | '!=' relational)
    // relational = add ( '<' add | '<=' add | '>' add | '>=' add)
    // add = mul ( '+' mul | '/' mul )
    // mul = unary ( '*' unary | '/' unary )
    // unary = ( '+' | '-' )? primary
    // primary = ( num | '(' expr ')' | ident )

    fn parseProgram(self: *Parser) !void {
        while(true){
            const func = try self.parseFunction() orelse {
                break;
            };
            self.functions.append(self.gpa, func) catch unreachable;
        }
    }

    fn parseFunction(self: *Parser) !?Function {
        if(self.currentTokenTag() != Token.Tag.tk_identifier){
            return null;
        }
        const name = self.getCurrentTokenSlice();
        _ = self.appendIdent(name, .{
            .tag = .function,
        });
        _ = self.nextToken();
        try self.expectToken(Token.Tag.tk_l_paren);
        try self.expectToken(Token.Tag.tk_r_paren);

        self.memory = 0;
        const body = try self.parseBlock();
        return Function{
            .name = name,
            .body = body,
            .memory = self.memory,
        };
    }

    fn parseStmt(self: *Parser) !usize {
        var node : usize = switch(self.currentTokenTag()){
            Token.Tag.tk_return => try self.parseReturnStmt(),
            Token.Tag.tk_if => try self.parseIf(),
            Token.Tag.tk_while => try self.parseWhile(),
            Token.Tag.tk_l_brace => try self.parseBlock(),
            Token.Tag.tk_for => try self.parseFor(),
            else => blk: {
                const stmt = self.parseExpr();
                try self.expectToken(Token.Tag.tk_semicoron);
                break :blk stmt;
            },
        };
        return node;
    }

    fn parseReturnStmt(self:*Parser) !usize {
        const node = self.addNode(.{
            .tag = .nd_return,
            .main_token = self.nextToken(),
            .lhs = self.parseExpr(),
        });

        try self.expectToken(Token.Tag.tk_semicoron);
        return node;
    }

    fn parseIf(self: *Parser) TokenError!usize {
        const main_token = self.nextToken();
        try self.expectToken(Token.Tag.tk_l_paren);
        const cond = self.parseExpr();
        try self.expectToken(Token.Tag.tk_r_paren);

        const then_blk = try self.parseStmt();
        if(self.currentTokenTag() != Token.Tag.tk_else){
            return self.addNode(.{
                .tag = .nd_if_simple,
                .main_token = main_token,
                .lhs = cond,
                .rhs = then_blk,
            });
        }

        try self.expectToken(Token.Tag.tk_else);
        return self.addNode(.{
            .tag = .nd_if,
            .main_token = main_token,
            .lhs = cond,
            .rhs = self.addNode(.{
                .tag = .nd_then_else,
                .main_token = self.nodes.items(.main_token)[then_blk],
                .lhs = then_blk,
                .rhs = try self.parseStmt(),
            })
        });
    }

    fn parseWhile(self: *Parser) TokenError!usize {
        const main_token = self.nextToken();
        try self.expectToken(Token.Tag.tk_l_paren);
        const cond = self.parseExpr();
        try self.expectToken(Token.Tag.tk_r_paren);

        return self.addNode(.{
            .tag = .nd_while,
            .main_token = main_token,
            .lhs = cond,
            .rhs = try self.parseStmt(),
        });
    }

    fn parseBlock(self: *Parser) TokenError!usize {
        const main_token = self.nextToken();
        var data = ExtraData{};
        data.body = Stmts.init(self.gpa);
        
        while(self.currentTokenTag() != Token.Tag.tk_r_brace){
            const stmt = try self.parseStmt();
            data.body.append(stmt) catch unreachable;
        }
        try self.expectToken(Token.Tag.tk_r_brace);

        return self.addNode(.{
            .tag = .nd_block,
            .main_token = main_token,
            .data = self.addExtraData(data),
        });
    }

    fn parseFor(self: *Parser) TokenError!usize {
        const main_token = self.nextToken();
        try self.expectToken(.tk_l_paren);
        
        // initialize
        const init_stmt = self.parseExpr();
        try self.expectToken(.tk_semicoron);

        // cond
        const cond = self.parseExpr();
        try self.expectToken(.tk_semicoron);

        // increment
        const inc = self.parseExpr();
        try self.expectToken(.tk_r_paren);

        return self.addNode(.{
            .tag = .nd_for,
            .main_token = main_token,
            .lhs = try self.parseStmt(),
            .data = self.addExtraData(.{
                .init = init_stmt,
                .cond = cond,
                .inc = inc,
            }),
        });
    }

    fn parseExpr(self: *Parser) usize {
        return self.parseAssign();
    }

    fn parseAssign(self: *Parser) usize {
        var lhs = self.parseEquality();
        if(self.currentTokenTag() == Token.Tag.tk_assign){
            lhs = self.addNode(.{
                .tag = .nd_assign,
                .main_token = self.nextToken(),
                .lhs = lhs,
                .rhs = self.parseAssign(),
            });
        }
        return lhs;
    }

    fn parseEquality(self: *Parser) usize {
        var lhs = self.parseRelational();

        while(true){
            switch(self.currentTokenTag()){
                .tk_equal => {
                    lhs = self.addNode(.{
                        .tag = .nd_equal,
                        .main_token = self.nextToken(),
                        .lhs = lhs,
                        .rhs = self.parseRelational(),
                    });
                },
                .tk_not_equal => {
                    lhs = self.addNode(.{
                        .tag = .nd_not_equal,
                        .main_token = self.nextToken(),
                        .lhs = lhs,
                        .rhs = self.parseRelational(),
                    });
                },
                else => return lhs,
            }
        }
    }

    fn parseRelational(self: *Parser) usize {
        var lhs = self.parseAdd();

        while(true){
            switch(self.currentTokenTag()){
                .tk_l_angle_bracket => {
                    lhs = self.addNode(.{
                        .tag = .nd_gt,
                        .main_token = self.nextToken(),
                        .lhs = lhs,
                        .rhs = self.parseAdd(),
                    });
                },
                .tk_l_angle_bracket_equal => {
                    lhs = self.addNode(.{
                        .tag = .nd_ge,
                        .main_token = self.nextToken(),
                        .lhs = lhs,
                        .rhs = self.parseAdd(),
                    });
                },
                .tk_r_angle_bracket => {
                    lhs = self.addNode(.{
                        .tag = .nd_gt,
                        .main_token = self.nextToken(),
                        .lhs = self.parseAdd(),
                        .rhs = lhs,
                    });
                },
                .tk_r_angle_bracket_equal => {
                    lhs = self.addNode(.{
                        .tag = .nd_ge,
                        .main_token = self.nextToken(),
                        .lhs = self.parseAdd(),
                        .rhs = lhs,
                    });
                },
                else => return lhs,            
            }
        }
    }

    fn parseAdd(self: *Parser) usize {
        var lhs = self.parseMultiple();

        while(true) {
            switch(self.tokens.items(.tag)[self.tkidx]){
                .tk_add => {
                    lhs = self.addNode(.{
                        .tag = .nd_add,
                        .main_token = self.nextToken(),
                        .lhs = lhs,
                        .rhs = self.parseMultiple(),
                    });
                },
                .tk_sub => {
                    lhs = self.addNode(.{
                        .tag = .nd_sub,
                        .main_token = self.nextToken(),
                        .lhs = lhs,
                        .rhs = self.parseMultiple(),
                    });
                },
                else => return lhs,
            }
        }
        
    }

    fn parseMultiple(self: *Parser) usize {
        var lhs = self.parseUnary() catch unreachable;

        while(true) {
            switch(self.currentTokenTag()){
                .tk_mul => {
                    lhs = self.addNode(.{
                        .tag = .nd_mul,
                        .main_token = self.nextToken(),
                        .lhs = lhs,
                        .rhs = self.parseUnary() catch unreachable,
                    });
                },
                .tk_div=> {
                    lhs = self.addNode(.{
                        .tag = .nd_div,
                        .main_token = self.nextToken(),
                        .lhs = lhs,
                        .rhs = self.parseUnary()  catch unreachable,
                    });
                },
                else => return lhs,
            }
        }
    }

    fn parseUnary(self: *Parser) !usize {
        if(self.currentTokenTag() == Token.Tag.tk_add){
            _ = self.nextToken();
            return self.parsePrimary();
        } else if(self.currentTokenTag() == Token.Tag.tk_sub){
            return self.addNode(.{
                .tag = .nd_sub,
                .main_token = self.nextToken(),
                .lhs = self.addNodeImm(0),
                .rhs = self.parsePrimary() catch unreachable,
            });
        } else {
            return self.parsePrimary() catch unreachable;
        }
    }

    fn parseCallFunction(self: *Parser) !usize {
        const main_token = self.nextToken();
        try self.expectToken(Token.Tag.tk_l_paren);
        try self.expectToken(Token.Tag.tk_r_paren);

        return self.addNode(.{
            .tag = .nd_call_function,
            .main_token = main_token,
        });
    }

    fn parsePrimary(self: *Parser) !usize {
        switch(self.currentTokenTag()){
            .tk_identifier => {
                const name = self.getCurrentTokenSlice();
                const ident = self.findIdent(name);

                if(ident) |i| {
                    switch(self.idents.items(.tag)[i]){
                        .local_variable => {
                            return self.addNode(Node{
                                .tag = .nd_lvar,
                                .main_token = self.nextToken(),
                                .ident = i,
                            });
                        },
                        .function => {
                            return try self.parseCallFunction();
                        },
                    }
                } else {
                    const add_ident = self.appendIdent(name, Ident { .tag = .local_variable, .size = 8, .offset = self.memory });

                    return self.addNode(Node{
                        .tag = .nd_lvar,
                        .main_token = self.nextToken(),
                        .ident = add_ident,
                    });
                }
            },
            .tk_num => {
                const main_token = self.nextToken();
                const tk_start = self.tokens.items(.start)[main_token];

                var tokenizer = Tokenizer.Tokenizer.init(self.source);
                const val = tokenizer.getNumValue(tk_start);

                return self.addNode(Node {
                    .tag = .nd_num,
                    .main_token = main_token,
                    .val = val,
                });
            },
            .tk_l_paren => {
                const main_token = self.nextToken();
                const node = self.parseExpr();
                self.nodes.items(.main_token)[node] = main_token;

                try self.expectToken(Token.Tag.tk_r_paren);
                return node;
            },
            else => {
                _ = try stderr.print("{}\n", .{self.currentTokenTag()});
                return TokenError.UnexpectedToken;
            },
        }
    }
};

test "abc" {
    var dict = std.StringHashMap(usize).init(std.heap.page_allocator); 
    const abs = "abcabc";
    dict.put(abs[0..1], 2) catch unreachable; 
    const data = dict.get(abs[3..4]);
    if(data) |d| {
        _ = stdout.print("{}\n", .{d}) catch unreachable;
    }
}