module ppl.misc.JsonWriter;

import ppl.internal;
import std.json;

final class JsonWriter {

    static string toString(Module m) {

        auto w = new JsonWriter;
        JSONValue v;
        w.recurse(m, v);

        return v.toJSON(true, JSONOptions.none);
    }

    void visit(AddressOf n, ref JSONValue v) {

    }
    void visit(Array n, ref JSONValue v) {

    }
    void visit(As n, ref JSONValue v) {

    }
    void visit(Binary n, ref JSONValue v) {
        v["op"] = n.op.value;
    }
    void visit(Break n, ref JSONValue v) {

    }
    void visit(BuiltinFunc n, ref JSONValue v) {

    }
    void visit(Call n, ref JSONValue v) {
        v["name"]   = n.name;
        v["target"] = toJson(n.target);
    }
    void visit(Case n, ref JSONValue v) {

    }
    void visit(Class n, ref JSONValue v) {

    }
    void visit(Composite n, ref JSONValue v) {
        v["kind"] = "%s".format(n.usage);
    }
    void visit(Constructor n, ref JSONValue v) {

    }
    void visit(Continue n, ref JSONValue v) {

    }
    void visit(Dot n, ref JSONValue v) {

    }
    void visit(Enum n, ref JSONValue v) {

    }
    void visit(EnumMember n, ref JSONValue v) {

    }
    void visit(EnumMemberValue n, ref JSONValue v) {

    }
    void visit(ExpressionRef n, ref JSONValue v) {

    }
    void visit(Function n, ref JSONValue v) {
        v["name"]   = n.name;
        setAccess(n.access, v);
        if(n.isStatic) v["static"] = true;
        if(n.isExtern) v["extern"] = true;
        v["type"] = toJson(n.getType());
    }
    void visit(FunctionType n, ref JSONValue v) {

    }
    void visit(Module n, ref JSONValue v) {
        v["name"]   = n.canonicalName;
    }
    void visit(Identifier n, ref JSONValue v) {
        v["name"] = n.name;
        v["type"] = toJson(n.getType());
        v["target"] = toJson(n.target);
    }
    void visit(If n, ref JSONValue v) {

    }
    void visit(Index n, ref JSONValue v) {

    }
    void visit(Initialiser n, ref JSONValue v) {

    }
    void visit(Is n, ref JSONValue v) {

    }
    void visit(Lambda n, ref JSONValue v) {

    }
    void visit(LiteralArray n, ref JSONValue v) {

    }
    void visit(LiteralFunction n, ref JSONValue v) {

    }
    void visit(LiteralNull n, ref JSONValue v) {

    }
    void visit(LiteralNumber n, ref JSONValue v) {
        v["value"]  = n.value.getString;
        v["type"]   = toJson(n.type);
    }
    void visit(LiteralString n, ref JSONValue v) {
        v["value"] =  n.value;
        if(n.enc == LiteralString.Encoding.REGEX) v["encoding"] = "REGEX";
     }
    void visit(LiteralTuple n, ref JSONValue v) {

    }
    void visit(Loop n, ref JSONValue v) {

    }
    void visit(ModuleAlias n, ref JSONValue v) {

    }
    void visit(Parameters n, ref JSONValue v) {

    }
    void visit(Return n, ref JSONValue v) {

    }
    void visit(Select n, ref JSONValue v) {

    }
    void visit(Struct n, ref JSONValue v) {
        v["name"]   = n.name;
        setAccess(n.access, v);
    }
    void visit(Tuple n, ref JSONValue v) {

    }
    void visit(TypeExpr n, ref JSONValue v) {
        v["type"] = toJson(n.type);
    }
    void visit(Unary n, ref JSONValue v) {
        v["op"] = n.op.value;
    }
    void visit(ValueOf n, ref JSONValue v) {

    }
    void visit(Variable n, ref JSONValue v) {
        v["name"]   = n.name;
        v["type"]   = toJson(n.type);
        setAccess(n.access, v);
        if(n.isStatic) v["static"] = true;
        if(n.isConst) v["const"]  = true;
    }
private:
    void recurse(ASTNode n, ref JSONValue v) {

        v["id"] = "%s".format(n.id());
        v["nid"] = n.nid;

        dynamicDispatch!("visit",ASTNode)(n, this, (it) {
            writefln("visit function missing: visit(%s)".format(typeid(n)));
        }, v);

        if(!n.hasChildren) return;

        auto vals = new JSONValue[n.children.length];
        v["zchildren"] = vals;

        foreach(i, ch; n.children) {
            JSONValue c;
            recurse(ch, c);
            vals[i] = c;
        }
    }
    void setAccess(Access a, ref JSONValue v) {
        if(a.isPublic) v["public"] = true;
    }
    JSONValue toJson(Target t) {
        JSONValue v;
        v["resolved"] = t.isResolved;
        if(t.isResolved) {
            v["kind"] = t.isVariable() ? "variable" : "function";
            v["nid"] = t.isVariable() ? t.getVariable().nid : t.getFunction().nid;
        }
        return v;
    }
    JSONValue toJson(Type n) {
        JSONValue v;

        if(n.isUnknown) {
            v["id"] = "UNKNOWN";
        } else if(n.isPtr) {
            v = toJson(n.as!Pointer.decoratedType);
            v["ptr_depth"] = n.as!Pointer.getPtrDepth();
        } else if(n.isAlias) {
            v["id"] = "ALIAS";
        } else if(n.isArray) {
            auto a = n.as!Array;
            v["id"] = "ARRAY";
            v["element_type"] = toJson(a.subtype);
        } else if(n.isBasicType) {
            v["id"] = g_typeToString[n.as!BasicType.type];
        } else if(n.isTuple) {
            v["id"] = "TUPLE";
        } else if(n.isStruct) {
            auto ns = n.as!Struct;
            v["id"] = "STRUCT";
            v["name"] = ns.name;
            v["module"] = ns.moduleName;
            v["nid"] = ns.nid;
        } else if(n.isClass) {
            auto ns = n.as!Class;
            v["id"] = "CLASS";
            v["name"] = ns.name;
            v["module"] = ns.moduleName;
            v["nid"] = ns.nid;
        } else if(n.isEnum) {
            auto e = n.as!Enum;
            v["id"] = "ENUM";
            v["name"] = e.name;
            v["nid"] = e.nid;
        } else if(n.isFunction) {
            auto f = n.as!FunctionType;
            v["id"] = "FUNCTION_TYPE";
            v["returnType"] = toJson(f.returnType());
        }
        return v;
    }
}
