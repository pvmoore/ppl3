module ppl.Attribute;

import ppl.internal;

T get(T)(Attribute[] attribs) {
    foreach(a; attribs) if(a.isA!T) return a.as!T;
    return null;
}

abstract class Attribute {
    enum Type {
        INLINE, NOINLINE,
        LAZY, MEMOIZE, MODULE, NOTNULL,
        PACKED, POD, PROFILE, MIN, MAX, NOOPT
    }
    string name;
    Type type;
}

/// --inline
/// Applies to functions
final class InlineAttribute : Attribute {
    this() {
        name = "--inline";
        type = Type.INLINE;
    }
}
/// --noinline
/// Applies to functions
final class NoInlineAttribute : Attribute {
    this() {
        name = "--noinline";
        type = Type.NOINLINE;
    }
}
/// --lazy
/// Applies to function parameters
final class LazyAttribute : Attribute {
    this() {
        name = "--lazy";
        type = Type.LAZY;
    }
}
/// [[memoize]]
/// Applies to functions
final class MemoizeAttribute : Attribute {
    this() {
        name = "--memoize";
        type = Type.MEMOIZE;
    }
}
/// module_priority=1
/// Applies to current module
final class ModuleAttribute : Attribute {
    int priority;
    this() {
        name = "--module_priority";
        type = Type.MODULE;
    }
}
/// --notnull
/// Applies to functionparameters
final class NotNullAttribute : Attribute {
    this() {
        name = "--notnull";
        type = Type.NOTNULL;
    }
}
/// --packed
/// Applies to structs
final class PackedAttribute : Attribute {
    this() {
        name = "--packed";
        type = Type.PACKED;
    }
}
/// --pod
/// Applies to structs
final class PodAttribute : Attribute {
    this() {
        name = "--pod";
        type = Type.POD;
    }
}
/// --profile
/// Applies to functions
final class ProfileAttribute : Attribute {
    this() {
        name = "--profile";
        type = Type.PROFILE;
    }
}
/// --min=0
/// Applies to variables
final class MinAttribute : Attribute {
    long min;
    this() {
        name = "--min";
        type = Type.MIN;
    }
}
/// --max=100
/// Applies to variables
final class MaxAttribute : Attribute {
    long max;
    this() {
        name = "--max";
        type = Type.MAX;
    }
}
/// --noopt
/// Applies to functions
final class NoOptAttribute : Attribute {
    this() {
        name = "--noopt";
        type = Type.NOOPT;
    }
}
