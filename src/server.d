module server;
/**
 *  Runs a server socket that listens on a port. Provides the following:
 *
 *  - Compile project
 *  - Provide json errors
 *  - Provide json structure
 */
import ppl;
import std.stdio : writefln;

void main(string[] argv) {

    auto port = 8080;

    writefln("Server starting on port %s ...", port);



    writefln("Server exiting");
}
