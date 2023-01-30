const std = @import("std");
const err = @import("./error.zig");

const expect = std.testing.expect;

const TokenizeError = error {
    UnexpectedToken,
    NotANumber,
    OutOfBuffer,
};

const TokenKind = enum {
    TK_PUNCT,
    TK_NUM,
    TK_EOF
};

const Token = struct {
    kind: TokenKind,
    val: u32 = 0,
    str: []const u8 = undefined,
    pos: usize = 0,
    len: u32 = 0,
};

pub const Tokenizer = struct{
    buffer: []const u8,
    index: usize,
    tokens: std.ArrayList(Token) = undefined,
    idx: usize,

    fn getSlice(self: *Tokenizer, num: u32) ![]const u8{
        const start:usize = self.index;
        const end:usize = self.index + num;

        if(end > self.buffer.len){
            return error.OutOfBuffer;
        }

        return self.buffer[start..end];
    }

    pub fn init(buffer: [:0]const u8) Tokenizer {
        var tokenizer: Tokenizer = Tokenizer{
            .buffer = buffer,
            .index = 0,
            .idx = 0,
        };

        tokenizer.tokens = std.ArrayList(Token).init(std.heap.page_allocator);
        return tokenizer;
    }

    fn appendTokenNoVal(self: *Tokenizer, kind: TokenKind) void {
        self.tokens.append(
            Token {
                .kind = kind,
                .val = 0,
                .pos = self.index,
            }
        ) catch unreachable;
    }

    fn appendToken(self: *Tokenizer, kind: TokenKind, len: u32) !void {
        self.tokens.append(
            Token {
                .kind = kind,
                .val = 0,
                .str = try getSlice(self, len),
                .pos = self.index,
                .len = len,
            }
        ) catch unreachable;
    }

    fn appentTokenNum(self: *Tokenizer) !void {
        var digits: u32 = 0;
        while(true) : (digits += 1) {
            if(self.buffer.len <= self.index + digits){
                break;
            }

            const c = self.buffer[self.index + digits];
            if(!std.ascii.isDigit(c)){
                break;
            }
        }

        if(digits == 0) {
            return TokenizeError.NotANumber;
        }

        const num_slice = getSlice(self, digits) catch unreachable;
        const val = std.fmt.parseUnsigned(u32, num_slice, 10) catch unreachable;
        self.index += digits - 1;
        self.tokens.append(
            Token {
                .kind = TokenKind.TK_NUM,
                .val = val,
                .pos = self.index - (digits - 1),
                .len = digits,
            }
        ) catch unreachable;
    }

    pub fn tokenize(self: *Tokenizer) !void {
        self.index = 0;
        while(true) : (self.index += 1) {
            if(self.index == self.buffer.len){
                appendTokenNoVal(self, TokenKind.TK_EOF);
                return;
            }

            const c = self.buffer[self.index];

            switch(c){
                0 => {
                    appendTokenNoVal(self, TokenKind.TK_EOF);
                    return;
                },
                '+', '-' => {
                    try appendToken(self, TokenKind.TK_PUNCT, 1);
                },
                ' ', '\t', '\r', '\n' => {
                    continue;
                },
                '0'...'9' => {
                    try appentTokenNum(self);
                },
                else => {
                    return TokenizeError.UnexpectedToken;
                }
            }
        }
    }

    pub fn consume(self: *Tokenizer, op: u32) bool {
        const tok: Token = self.tokens.items[self.idx];
        if((tok.kind != TokenKind.TK_PUNCT)
            or (tok.str[0] != op)){
            return false;
        }
        self.idx += 1;
        return true;
    }

    pub fn expect(self: *Tokenizer, op: u32) !void {
        const tok: Token = self.tokens.items[self.idx];
        if((tok.kind != TokenKind.TK_PUNCT)
            or (tok.str[0] != op))
        {
            try err.error_at(self.buffer[0..self.buffer.len:0], tok.pos, "error: unexpected token.\n", .{});
            return TokenizeError.UnexpectedToken;
        }
        self.idx += 1;
    }

    pub fn expect_number(self: *Tokenizer) !u32 {
        const tok: Token = self.tokens.items[self.idx];
        if(tok.kind == TokenKind.TK_NUM){
            self.idx += 1;
            return tok.val;
        } else {
            try err.error_at(self.buffer[0..self.buffer.len:0], tok.pos, "error: unexpected token.\n", .{});
            return TokenizeError.UnexpectedToken;
        }
    }

    pub fn is_eof(self: *Tokenizer) bool {
        const tok: Token = self.tokens.items[self.idx];
        return tok.kind == TokenKind.TK_EOF;
    }
};

test "Tokenizer test" {
    const str = "3+3";
    var tokenizer = Tokenizer.init(str);
    try tokenizer.tokenize();

    _ = try tokenizer.expect_number();
    _ = try tokenizer.expect('+');
    _ = try tokenizer.expect_number();
    _ = try expect(tokenizer.is_eof());
}