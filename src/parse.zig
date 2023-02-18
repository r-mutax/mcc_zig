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
        const tk = self.nodes.items(.main_token)[node];
        const tk_start = self.tokens.items(.start)[tk];

        var tokenizer = Tokenizer.Tokenizer.init(self.source);
        const result = tokenizer.getNumValue(tk_start);
        return result;
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

    fn nextToken(self: *Parser) usize {
        const result = self.tkidx;
        self.tkidx += 1;
        return result;
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
        var lhs = self.parsePrimary().?;

        while(true) {
            switch(self.tokens.items(.tag)[self.tkidx]){
                .tk_mul => {
                    lhs = self.addNode(.{
                        .tag = .nd_mul,
                        .main_token = self.nextToken(),
                        .lhs = lhs,
                        .rhs = self.parsePrimary().?,
                    });
                },
                .tk_div=> {
                    lhs = self.addNode(.{
                        .tag = .nd_div,
                        .main_token = self.nextToken(),
                        .lhs = lhs,
                        .rhs = self.parsePrimary().?,
                    });
                },
                else => return lhs,
            }
        }
    }

    fn parsePrimary(self: *Parser) ?usize {
        switch(self.tokens.items(.tag)[self.tkidx]){
            .tk_num => return self.addNode(.{
                        .tag = .nd_num,
                        .main_token = self.nextToken(),
                    }),
            else => return null,
        }
    }
};
