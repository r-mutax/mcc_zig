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
    };
    main_token: usize,
    lhs: usize = undefined, // NodeLists index
    rhs: usize = undefined, // NodeLists index
    val: u32 = 0,           // value of nodes(in nd_num)
    tag: Tag,
    ident: usize = undefined,
};

pub const Ident = struct {
    const Tag = enum {
        local_variable,
    };
    size: u32,
    tag: Tag,
    offset: u32,
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
pub const Stmts = std.ArrayList(usize);

pub const Function = struct {
    name: [:0] const u8,
    stmts: Stmts,
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
        self.parseProgram();
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

    pub fn getFuncName(self:*Parser, idx:usize) [:0] const u8 {
        return self.functions.items(.name)[idx];
    }

    pub fn getFuncMemory(self: *Parser, idx: usize) u32 {
        return self.functions.items(.memory)[idx];
    }

    pub fn getFunctionStmts(self:*Parser, idx:usize) Stmts {
        return self.functions.items(.stmts)[idx];
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

    fn nextToken(self: *Parser) usize {
        const result = self.tkidx;
        self.tkidx += 1;
        return result;
    }

    fn currentTokenTag(self: *Parser) Token.Tag {
        return self.tokens.items(.tag)[self.tkidx];
    }

    fn getCurrentTokenSlice(self: *Parser) [] const u8 {
        const main_token = self.tkidx;
        const start = self.tokens.items(.start)[main_token];
        var tokenizer = Tokenizer.Tokenizer.init(self.source);
        
        const name = tokenizer.getSlice(start);
        return name;
    }

    // program = stmt*
    // stmt = expr ';' | 'return' expr ';'
    // expr = assign
    // assign = equality ('=' assign)?
    // equality = relational ( '==' relational | '!=' relational)
    // relational = add ( '<' add | '<=' add | '>' add | '>=' add)
    // add = mul ( '+' mul | '/' mul )
    // mul = unary ( '*' unary | '/' unary )
    // unary = ( '+' | '-' )? primary
    // primary = ( num | '(' expr ')' )

    fn parseProgram(self: *Parser) void {
        var stmts = Stmts.init(self.gpa);
        while(self.currentTokenTag() != Token.Tag.tk_eof) {
            const stmt = self.parseStmt() catch unreachable;
            stmts.append(stmt) catch unreachable;
        }
        
        self.functions.append(self.gpa, .{
            .name = "main",
            .stmts = stmts,
            .memory = self.memory,
        }) catch unreachable;
    }

    fn parseStmt(self: *Parser) !usize {
        var node : usize = 0;
        if(self.currentTokenTag() == Token.Tag.tk_return){
            node = self.addNode(.{
                .tag = .nd_return,
                .main_token = self.nextToken(),
                .lhs = self.parseExpr(),
            });
        } else {
            node = self.parseExpr();
        }

        if(self.currentTokenTag() != Token.Tag.tk_semicoron){
            return TokenError.UnexpectedToken;
        }
        _ = self.nextToken();   // skip semicoron
        return node;
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

    fn parsePrimary(self: *Parser) !usize {
        switch(self.currentTokenTag()){
            .tk_identifier => {
                const name = self.getCurrentTokenSlice();
                const ident = self.findIdent(name);

                if(ident) |i| {
                    return self.addNode(Node{
                        .tag = .nd_lvar,
                        .main_token = self.nextToken(),
                        .ident = i,
                    });
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

                if(self.currentTokenTag() != Token.Tag.tk_r_paren){
                    return TokenError.UnexpectedToken;
                }
                _ = self.nextToken();
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