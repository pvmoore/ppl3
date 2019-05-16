module ppl.parse.ParseAttribute;

import ppl.internal;

final class ParseAttribute {
private:
    Module module_;
public:
    this(Module m) {
        this.module_ = m;
    }
    void parse(Tokens t, ASTNode parent) {

        /// [[
        t.skip(TT.DBL_LSQBRACKET);

        string name = t.value;
        t.next;

        switch(name) {
            case "inline":
                parseInlineAttribute(t);
                break;
            case "noinline":
                parseNoInlineAttribute(t);
                break;
            case "module":
                parseModuleAttribute(t, parent);
                break;
            case "packed":
                parsePackedAttribute(t);
                break;
            case "pod":
                parsePodAttribute(t);
                break;
            case "noopt":
                parseNoOpt(t);
                break;
            default:
                t.prev;
                errorBadSyntax(module_, t, "Unknown attribute '%s'".format(name));
                break;
        }

        t.skip(TT.DBL_RSQBRACKET);
    }
private:
    /// [[inline]]
    void parseInlineAttribute(Tokens t) {
        auto a = new InlineAttribute;

        t.addAttribute(a);
    }
    /// [[noinline]]
    void parseNoInlineAttribute(Tokens t) {
        auto a = new NoInlineAttribute;

        t.addAttribute(a);
    }
    void parseModuleAttribute(Tokens t, ASTNode parent) {
        import std.array : replace;

        auto a = new ModuleAttribute;

        /// Add this attribute to the current module directly
        module_.attributes ~= a;

        if(!parent.isModule) {
            t.prev;
            module_.addError(t, "[[module]] attribute must be at module scope", true);
            t.next;
        }

        foreach(k,v; getNameValueProperties(t, "module", ["priority"])) {
            if(k=="priority") {
                a.priority = v.replace("_","").to!int;
            }
        }
    }
    void parsePackedAttribute(Tokens t) {
        auto a = new PackedAttribute;

        t.addAttribute(a);
    }
    void parsePodAttribute(Tokens t) {
        auto a = new PodAttribute;

        t.addAttribute(a);
    }
    void parseNoOpt(Tokens t) {
        auto a = new NoOptAttribute;

        t.addAttribute(a);
    }
    //string getValueProperty(Tokens t) {
    //    /// (
    //    t.skip(TT.LBRACKET);
    //
    //    string value = t.value;
    //    t.next;
    //
    //    /// )
    //    t.skip(TT.RBRACKET);
    //
    //    return value;
    //}
    string[string] getNameValueProperties(Tokens t, string name, string[] keys) {
        string[string] props;

        import common : contains;

        ///
        while(t.type!=TT.DBL_RSQBRACKET) {

            /// name
            string prop = t.value;
            if(!keys.contains(prop)) {
                module_.addError(t, "Unknown [[%s]] property '%s'".format(name, prop), true);
            }
            t.next;

            /// =
            t.skip(TT.EQUALS);

            /// value
            props[prop] = t.value;
            t.next;

            t.expect(TT.COMMA, TT.DBL_RSQBRACKET);
            if(t.type==TT.COMMA) t.next;
        }

        return props;
    }
}