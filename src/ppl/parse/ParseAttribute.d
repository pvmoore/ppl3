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

        /// !!
        t.skip(TT.DBL_EXCLAMATION);

        string name = t.value;
        t.next;

            switch(name) {
            case "inline":
                parseInline(t);
                break;
            case "noinline":
                parseNoInline(t);
                break;
            case "module_priority":
                parseModulePriority(t, parent);
                break;
            case "packed":
                parsePacked(t);
                break;
            case "pod":
                parsePod(t);
                break;
            case "noopt":
                parseNoOpt(t);
                break;
            default:
                t.prev;
                errorBadSyntax(module_, t, "Unknown attribute '%s'".format(name));
                break;
        }
    }
private:
    /// !!inline
    void parseInline(Tokens t) {
        t.addAttribute(new InlineAttribute);
    }
    /// !!noinline
    void parseNoInline(Tokens t) {
        t.addAttribute(new NoInlineAttribute);
    }
    /// !!module_priority
    void parseModulePriority(Tokens t, ASTNode parent) {

        auto a = new ModuleAttribute;

        /// Add this attribute to the current module directly
        module_.attributes ~= a;

        if(!parent.isModule) {
            t.prev;
            module_.addError(t, "!!module_priority attribute must be at module scope", true);
            t.next;
        }

        a.priority = getIntProperty(t);
    }
    /// !!packed
    void parsePacked(Tokens t) {
        t.addAttribute(new PackedAttribute);
    }
    /// !!pod
    void parsePod(Tokens t) {
        t.addAttribute(new PodAttribute);
    }
    /// !!noopt
    void parseNoOpt(Tokens t) {
        t.addAttribute(new NoOptAttribute);
    }
    int getIntProperty(Tokens t) {
        import std.array : replace;

        /// =
        t.skip(TT.EQUALS);

        /// value
        int prop = t.value.replace("_","").to!int;
        t.next;

        return prop;
    }
}