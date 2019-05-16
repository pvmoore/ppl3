module ppl.CompileTimeConstant;

import ppl.internal;

interface CompileTimeConstant {
    Expression copy();
    bool isTrue();
    Type getType();
}