module ppl.Container;

import ppl.internal;
///
/// Variable or Function container.
///
/// Module, LiteralFunction, Struct, Class or Tuple
///
interface Container {
    NodeID id() const;

    final ASTNode node() { return cast(ASTNode)this; }

    final bool isFunction() { return node().id==NodeID.LITERAL_FUNCTION; }
    final bool isModule()   { return node().id==NodeID.MODULE; }
    final bool isStruct()   { return node().id==NodeID.STRUCT; }
    final bool isClass()    { return node().id==NodeID.CLASS; }
    final bool isTuple()    { return node().id==NodeID.TUPLE; }

    final bool containsPosition(Position them) {
        auto n = node();

        assert(n.isA!LiteralFunction || n.isA!Module || n.isA!Struct || n.isA!Class || n.isA!Tuple);

        if(n.line==-1 || n.column==-1) return false;
        if(n.endPos.isInvalid()) return false;

        auto start = Position(n.line, n.column);

        return !them.isBefore(start) && !them.isAfter(n.endPos);
    }
}
