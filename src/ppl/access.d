module ppl.Access;

import ppl.internal;

enum Access {
    PUBLIC,
    PRIVATE
}

bool isPublic(Access a)   { return a==Access.PUBLIC; }
bool isPrivate(Access a)  { return a==Access.PRIVATE; }

string toString(Access a) {
    return "%s".format(a).toLower;
}

Access getAccess(ASTNode n) {
    switch(n.id) with(NodeID) {
        case STRUCT:
            return n.as!Struct.access;
        case ALIAS:
            return n.as!Alias.access;
        case ENUM:
            return n.as!Enum.access;
        case FUNCTION:
            return n.as!Function.access;
        case VARIABLE:
            return n.as!Variable.access;
        case TUPLE:
            return Access.PRIVATE;
        default:
            assert(false, "implement me %s".format(n.id));
    }
}