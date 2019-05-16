# this file is a struct (the name is the path+filename), there are no modules

containers = import std.containers   # const struct containers - every file is a struct

List = containers.List  # const struct

# var variables are internally modifiable but externally readonly

# we are inside a struct so anything at this level is at struct member scope
var int myValue

extern putchar = fn(int)int          # extern implies no body
extern printf = fn(byte[*] fmt, ... args)int  # c-style byte array, vararg

pub string = [[packed]] struct  {
    @coroPrelude()
    var byte[*] ptr        # var - can only be modified by member functions
    var int length         #
    
    # member function can be called using dot syntax: "hello".isEmpty()
    pub isEmpty = fn(this) bool { # _this_ is inferred as string (passed by value)
        ret length == 0    
    }
    pub contains = fn(ref this, byte needle) bool { # _this_ is inferred as ref string (passed by reference)
        ret false
    }
}
pub Colour = struct {
    pub int a                   # const int
    pub b = 0                   # const int
    var c = 0                   # variable int    
    var bool flag = false       # variable bool 
    dance = fn()int {       # private const function no params returns int
        ret 2   
    }
    var fn(int)void setMe  # function ptr variable
}
pub main = fn(string[] args) int { # const string array returning int
    ret 0
}
pub foo = fn() {         # no params, void return 
    a = 0               # const int
    b = 0 as byte       # const byte with cast

    var b = true    # variable bool

    IntRef = ref int    # IntRef is type const ref int
}
# private function takes List by reference
bar = fn(ref List list, int arg) {}
    

#
#   c = max(int, a, b)
#
max = fn(type T, T a, T b) T    # generic function takes a type arg
    where T.isPrimitive()
{
    ret a
}
#   List(int) list = List(int)
#
pub List = fn(type T) {
    ret struct {
        var byte[*] array       # c_style byte array
        pub var int length      # internally writable, externally readable
        
        const @typeOf(this) myType = this       # const List(T)
        
        pub add = fn(ref this, T value) {   # return this is inferred
            array[length] = value
            length += 1
            ret this    # infer ref List(T)
        }
    }
}
#
#
isPrimitive = fn(type T) bool {
    ret select(T) {
        bool                : true
        byte,short,int,long : true
        float,double        : true
        else                : false
    }
}
# for
baz = fn() {
    array = [0,1,2,3]   # const int[4]
    for(array) v, i {
        assert array[i]==v
    }
    for(0..10) i {
        # use i (0 to 10 inclusive)
    }
    for(true) {   
        # while loop
    }
}
boz = fn() {
    array = [1,2,3]
    array.map() fn(it) { ret it as float }
}