module ppl.Position;

import ppl.internal;

struct Position {
    int line;
    int column;

    bool isValid() {
        return this != INVALID_POSITION;
    }
    bool isInvalid() {
        return !isValid();
    }
    void set(int line, int column) {
        this.line = line;
        this.column = column;
    }
    bool isBefore(Position p) {
        if(this==INVALID_POSITION) return false;
        if(p==INVALID_POSITION) return true;
        return line < p.line || (line==p.line && column < p.column);
    }
    bool isAfter(Position p) {
        if(this==INVALID_POSITION) return false;
        if(p==INVALID_POSITION) return true;
        return line > p.line || (line==p.line && column > p.column);
    }

    Position min(Position p) {
        return this.isBefore(p) ? this : p;
    }
    Position max(Position p) {
        return this.isAfter(p) ? this : p;
    }

    string toString() { return "%s,%s".format(line, column); }
}