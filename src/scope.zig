const std = @import("std");
const Allocator = std.mem.Allocator;

pub const ScopeError = error {
    return_from_grobal_scope,
};

pub const Ident = struct {
    const Tag = enum {
        local_variable,
        function,
        paramater,
    };
    size: u32 = undefined,
    tag: Tag,
    offset: u32 = undefined,
};
pub const IdentList = std.MultiArrayList(Ident);

pub const Scope = struct {
    dict: std.StringHashMap(usize),
    level: u32,
    parent: ?usize,
    offset: u32 = 0,
};
pub const ScopeList = std.MultiArrayList(Scope);

pub const ScopeManager = struct {
    gpa: Allocator,
    scidx: usize,
    memory: u32 = 0,
    level: u32,
    scopes: ScopeList = undefined,
    idents: IdentList = undefined,

    pub fn init(gpa: Allocator) ScopeManager {

        var result = ScopeManager {
            .gpa = gpa,
            .scidx = 0,
            .scopes = ScopeList{},
            .idents = IdentList{},
            .level = 0,
        };

        // create global scope
        result.scopes.append(gpa, .{
            .dict = std.StringHashMap(usize).init(gpa),
            .level = 0,
            .parent = null,
        }) catch unreachable;

        result.scidx = 0;
        return result;
    }

    fn genScope(self: *ScopeManager) void {
        const idx = self.scopes.len;
        self.scopes.append(self.gpa, .{
            .dict = std.StringHashMap(usize).init(self.gpa),
            .level = self.level + 1,
            .parent = self.scidx,
        }) catch unreachable;

        self.scidx = idx;
        self.level += 1;

        if(self.level == 1){
            self.memory = 0;
        }
    }

    pub fn startScope(self: *ScopeManager) void {
        self.genScope();
    }

    pub fn endScope(self: *ScopeManager) !void {
        const new_idx = self.scopes.items(.parent)[self.scidx];
        if(new_idx) |idx|{
            self.scidx = idx;
            self.level -= 1;
        } else {
            return ScopeError.return_from_grobal_scope;
        }
    }

    pub fn addIdent(self: *ScopeManager, name: [] const u8, ident: Ident) usize {
        if(self.level != 0){
            // local variable
            self.memory += ident.size;
        }

        const idx = self.idents.len;
        self.idents.append(self.gpa, ident) catch unreachable;

        var dict = self.scopes.items(.dict)[self.scidx];
        dict.put(name, idx) catch unreachable;
        self.scopes.items(.dict)[self.scidx] = dict;
        return idx;
    }

    pub fn getFuncMemory(self: *ScopeManager) u32 {
        return self.memory;
    }

    pub fn findIdent(self: *ScopeManager, name: [] const u8) ?usize {
        var idx = self.scidx;
        while(true){
            var dict = self.scopes.items(.dict)[idx];
            const ident = dict.get(name);
            if(ident) |i| {
                return i;
            }

            var parent = self.scopes.items(.parent)[idx];
            if(parent == null){
                return null;
            }

            idx = parent.?;
        }
    }

    pub fn getIdentTag(self: *ScopeManager, idx: usize) Ident.Tag {
        return self.idents.items(.tag)[idx];
    }

    pub fn getVariableOffset(self: *ScopeManager, idx: usize) u32 {
        return self.idents.items(.offset)[idx];
    }

    pub fn getFunctionMemorySize(self: *ScopeManager) u32 {
        return self.memory;
    }
};
