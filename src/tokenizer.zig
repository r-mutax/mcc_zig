const std = @import("std");
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
    val: u32,
    str: []const u8 = undefined,
};

const Tokenizer = struct{
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

    fn readNumber(self: *Tokenizer) !Token{
        var n:u32 = 0;

        // Search not a number
        while(true) : (n += 1) {
            if(self.buffer.len <= self.index + n){
                break;
            }
            const c: u8 = self.buffer[self.index + n];
            if(!std.ascii.isDigit(c)){
                break;
            }
        }

        if(n == 0){
            return TokenizeError.NotANumber;
        }

        const num_slice = getSlice(self, n) catch unreachable;
        const val = std.fmt.parseUnsigned(u32, num_slice, 10) catch unreachable;
        self.index += n;
        return Token {
            .kind = TokenKind.TK_NUM,
            .val = val,
        };
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

    pub fn tokenize(self: *Tokenizer) void {
        while(true) {
            var tok: Token = self.next() catch unreachable;
            self.tokens.append(tok) catch unreachable;

            if(tok.kind == TokenKind.TK_EOF){
                return;
            }
        }
    }

    pub fn expect_number(self: *Tokenizer) u32 {
        const tok: Token = self.tokens.items[self.idx];
        if(tok.kind == TokenKind.TK_NUM){
            self.idx += 1;
            return tok.val;
        } else {
            return false;
        }
    }

    pub fn getToken(self: *Tokenizer) Token {
        const tok: Token = self.tokens.items[self.idx];
        self.idx += 1;
        return tok;
    }

    pub fn next(self: *Tokenizer) TokenizeError ! Token {
        if(self.buffer.len <= self.index) {
            return Token{
                .kind = TokenKind.TK_EOF,
                .val = 0,
            };
        }

        const c = self.buffer[self.index];
        var result: Token = undefined;

        switch(c){
            0 => {
                return Token {
                    .kind = TokenKind.TK_EOF,
                    .val = 0,
                };
            },
            '+' => {
                result.kind = TokenKind.TK_PUNCT;
                result.str = try getSlice(self, 1);
                self.index += 1;
                return result;
            },
            '-' => {
                result.kind = TokenKind.TK_PUNCT;
                result.str = try getSlice(self, 1);
                self.index += 1;
                return result;
            },
            '0'...'9' => {
                return readNumber(self) catch unreachable;
            },
            else => {
                return Token {
                    .kind = TokenKind.TK_EOF,
                    .val = 0,
                };
            }
        }
    }
};

test "Tokenizer test" {
    const str = "3+3";
    var tokenizer = Tokenizer.init(str);
    tokenizer.tokenize();

    var kind_list = [_]TokenKind{
        TokenKind.TK_NUM,
        TokenKind.TK_PUNCT,
        TokenKind.TK_NUM,
        TokenKind.TK_EOF,
    };

    for(kind_list) | kind | {
        const tok = tokenizer.getToken();

        if(kind == TokenKind.TK_NUM){
            try expect(tok.val == 3);
        }
        try expect(kind == tok.kind);
    }
}