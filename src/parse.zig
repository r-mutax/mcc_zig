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
    };
    main_token: usize,
    lhs: usize = undefined, // NodeLists index
    rhs: usize = undefined, // NodeLists index
    val: u32 = 0,           // value of nodes(in nd_num)
    tag: Tag,
};
pub const Nodes = std.MultiArrayList(Node);

pub const Parser = struct {
    gpa: Allocator,
    source: [:0] const u8,
    tokens: TokenList = undefined,
    tkidx: usize,           // index of TokenList.
    root: usize,            // NodeList index of rootNode.
    nodes: Nodes = undefined,

    pub fn init(gpa: Allocator, source: [:0]const u8) Parser {
        return Parser {
            .gpa = gpa,
            .source = source,
            .tkidx = 0,
            .root = 0,
        };
    }

    pub fn parse(self: *Parser) usize {

        // トークンリストを作る
        self.tokens = TokenList{};
        self.nodes = Nodes{};

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

        // パースする
        self.root = self.parseExpr();
        return self.root;
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

    fn currentToken(self: *Parser) Token.Tag {
        return self.tokens.items(.tag)[self.tkidx];
    }

    fn parseExpr(self: *Parser) usize {
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
            switch(self.currentToken()){
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
        if(self.currentToken() == Token.Tag.tk_add){
            _ = self.nextToken();
            return self.parsePrimary();
        } else if(self.currentToken() == Token.Tag.tk_sub){
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
        switch(self.currentToken()){
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

                if(self.currentToken() != Token.Tag.tk_r_paren){
                    return TokenError.UnexpectedToken;
                }
                _ = self.nextToken();
                return node;
            },
            else => return TokenError.UnexpectedToken,
        }
    }
};
