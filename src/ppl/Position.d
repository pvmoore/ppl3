module ppl.Position;

import ppl.internal;

struct Position {
    int line;
    int column;
    bool isBefore(Position p) { return line < p.line || (line==p.line && column < p.column); }
    bool isAfter(Position p) { return line > p.line || (line==p.line && column > p.column); }
    string toString() { return "%s,%s".format(line, column); }
}