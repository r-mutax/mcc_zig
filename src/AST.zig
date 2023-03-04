const std = @import("std");
const AST = @This();

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

pub const NodeList = std.MultiArrayList(AST.Node);

