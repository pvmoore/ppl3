module ppl.Attribute;

import ppl.internal;

T get(T)(Attribute[] attribs) {
    foreach(a; attribs) if(a.isA!T) return a.as!T;
    return null;
}

abstract class Attribute {
    enum Type {
        INLINE, NOINLINE, LAZY, MEMOIZE, MODULE, NOTNULL, PACKED, POD, PROFILE, RANGE,
        NOOPT
    }
    string name;
    Type type;
}

/// [[inline]]
/// Applies to functions
final class InlineAttribute : Attribute {
    this() {
        name = "[[inline]]";
        type = Type.INLINE;
    }
}
/// [[noinline]]
/// Applies to functions
final class NoInlineAttribute : Attribute {
    this() {
        name = "[[noinline]]";
        type = Type.NOINLINE;
    }
}
/// @lazy
/// Applies to function parameters
final class LazyAttribute : Attribute {
    this() {
        name = "[[lazy]]";
        type = Type.LAZY;
    }
}
/// @memoize
/// Applies to functions
final class MemoizeAttribute : Attribute {
    this() {
        name = "[[memoize]]";
        type = Type.MEMOIZE;
    }
}
/// @module(priority=1)
/// Applies to current module
final class ModuleAttribute : Attribute {
    int priority;
    this() {
        name = "[[module]]";
        type = Type.MODULE;
    }
}
/// @notnull
final class NotNullAttribute : Attribute {
    this() {
        name = "[[notnull]]";
        type = Type.NOTNULL;
    }
}
/// @pack(true)
/// Applies to structs
final class PackedAttribute : Attribute {
    this() {
        name = "[[packed]]";
        type = Type.PACKED;
    }
}
final class PodAttribute : Attribute {
    this() {
        name = "[[pod]]";
        type = Type.POD;
    }
}
/// @profile
/// Applies to functions
final class ProfileAttribute : Attribute {
    this() {
        name = "[[profile]]";
        type = Type.PROFILE;
    }
}
/// @bounds(min=0, max=200)
/// Applies to variables
final class RangeAttribute : Attribute {
    this() {
        name = "[[range]]";
        type = Type.RANGE;
    }
}

final class NoOptAttribute : Attribute {
    this() {
        name = "[[noopt]]";
        type = Type.NOOPT;
    }
}
