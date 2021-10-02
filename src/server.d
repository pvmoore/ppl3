module server;
/**
 *  Runs a server socket that listens on a port. Provides the following:
 *
 *  - Compile project
 *  - Provide json errors
 *  - Provide suggestions
 */
import ppl.internal;
import std.socket;
import std.algorithm.iteration  : filter;
import std.stdio                : writefln;
import std.range                : array;
import std.format               : format;
import std.base64               : Base64URLNoPadding;
import std.json                 : JSONValue;
import std.conv                 : to;
import std.array                : split;
import common                   : From;

void main(string[] argv) {

    ushort port  = 6536;

    auto server = new Server(port);


    char[1024] buf;


    //writefln("value = %s", Base64URLNoPadding.encode(cast(ubyte[])"value", buf[]));

    //auto req = Request("GET", "/watch", "HTTP/1.1", ["directory":""]);
    //server.startIncrementalBuilder(req);

    server.startListening();



}

struct Request {
    string method;
    string path;
    string protocol;
    string[string] query;
    string[string] headers;
    string content;

    string getQueryValue(string key) {
        auto ptr = key in query;
        if(ptr) return *ptr;
        return "";
    }
    string getDecodedQueryValue(string key) {
        return cast(string)Base64URLNoPadding.decode(getQueryValue(key));
    }
    int getQueryIntValue(string key, int default_) {
        string value = getQueryValue(key);
        return value.length>0 ? value.to!int : default_;
    }

    string toString() {
        return "[Request %s %s %s query=%s (content = %s chars)]".format(method, protocol, path, query, content.length);
    }
}

final class Server : BuildState.IBuildStateListener {
private:
    ushort port;
    TcpSocket listener;
    SocketSet socketSet;
    Socket[] clients;
    bool isRunning = true;
    IncrementalBuilder builder;
    FileLogger log;

    Module[string] parsedModules;
    Module[string] resolvedModules;
public:
    this(ushort port) {
        this.port = port;
        this.log = new FileLogger(".logs/server.log");
    }
    void startListening() {
        scope(exit) {
            log.close();
        }

        listener = new TcpSocket();
        listener.blocking = true;
        listener.bind(new InternetAddress(port));
        listener.listen(10);

        socketSet = new SocketSet();

        log.push("Server listening on localhost:%s ...", port);

        while(isRunning) {
            socketSet.reset();
            socketSet.add(listener);

            // Remove closed sockets
            clients = clients.filter!(c=>c.isAlive).array;

            foreach(client; clients) {
                socketSet.add(client);
            }

            if(Socket.select(socketSet, null, null) > 0) {

                foreach(client; clients) {
                    if(socketSet.isSet(client)) {
                        handle(client);
                    }
                }
                if(socketSet.isSet(listener)) {
                    // the listener is ready to read, that means
                    // a new client wants to connect. We accept it here.
                    auto socket = listener.accept();
                    clients ~= socket;
                }
            }
        }
    }
    // IBuildStateListener
    override void buildFinished(BuildState state) {

        foreach(m; state.allModules()) {
            if(m.isParsed) {
                parsedModules[m.canonicalName] = m;
            }
            if(m.resolver.isResolved) {
                resolvedModules[m.canonicalName] = m;
            }
        }
        log.push("%s resolved, %s parsed", resolvedModules.length, parsedModules.length);

        if(state.hasErrors()) {

        } else {

        }
    }
private:
    void shutdown() {
        isRunning = false;
        listener.shutdown(SocketShutdown.BOTH);
        if(builder) builder.shutdown();
    }
    /**
     *   // standard input --> sent to server
     *   { "jsonrpc": "2.0", "method": "subtract", "params": [42, 23], "id": 1 }
     *
     *   // standard output <-- sent to client
     *   { "jsonrpc": "2.0", "result": 19, "id": 1 }
     */
    void handle(Socket socket) {
        log.push("Handling socket");

        string content = readAll(socket);
        log.push("content = %s", content);

        Request req = decodeRequest(content);
        log.push("%s", req);

        string response;

        switch(req.path) {
            case "/quit":
                shutdown();
                break;
            case "/watch":
                startIncrementalBuilder(req);
                break;
            case "/problems":
                returnErrors(req);
                break;
            case "/suggestions":
                response = returnSuggestions(req);
                break;
            default:
                break;
        }

        log.push("returning: %s", response);

        socket.send("HTTP/1.1 200 OK\r\n");
        socket.send("Connection: close\r\n");
        socket.send("Content-type: application/json\r\n");
        socket.send("Content-length: %s\r\n".format(response.length));
        socket.send("\r\n");
        if(response) {
            socket.send(response);
        }

        socket.shutdown(SocketShutdown.BOTH);
        socket.close();
    }
    string readAll(Socket socket) {
        char[2048] buffer;
        char[] data;
        while(true) {
            auto got = socket.receive(buffer);
            if(got==Socket.ERROR) break;
            data ~= buffer[0..got];
            if(got < buffer.length) break;
        }
        return cast(string)data;
    }
    Request decodeRequest(string text) {
        Request r;

        import std.string : splitLines, indexOf, strip, KeepTerminator;
        import std.array : split, join;

        const lines = splitLines(text, KeepTerminator.yes);

        const tokens = lines[0].split();
        r.method = tokens[0];
        r.path = tokens[1];
        r.protocol = tokens[2];

        const q = r.path.indexOf('?');
        if(q!=-1) {
            auto query = r.path[q+1..$];
            r.path = r.path[0..q];

            foreach(p; query.split("&")) {
                auto toks = p.split("=");
                r.query[toks[0]] = toks[1];
            }
        }

        foreach(i, l; lines[1..$]) {
            if(l.strip().length==0) {
                r.content = lines[i+2..$].join();
                break;
            }

            const colon = l.indexOf(':');
            const key   = l[0..colon].strip();
            const value = l[colon+1..$].strip();

            r.headers[key] = value;
        }


        //log.push("headers = %s", r.headers);

        //log.push("%s", r.toString());

        return r;
    }
    /**
     *  ?directory=
     */
    void startIncrementalBuilder(Request req) {

        // Stop any existing builder
        if(this.builder) {
            this.builder.shutdown();
        }

        string directory  = req.getDecodedQueryValue("directory");

        directory = "\\pvmoore\\d\\apps\\ppl3\\projects\\test\\";

        if(false==From!"std.file".exists(directory)) {
            log.push("directory '%s' does not exist", directory);
            return;
        }

        string configFile = directory ~ "config.toml";
        log.push("Reading config from %s", configFile);

        auto ppl = PPL3.instance();

        auto config = new ConfigReader(configFile).read();
        config.writeASM = false;
        config.writeOBJ = false;
        config.writeAST = false;
        config.writeIR  = false;
        config.writeJSON = false;

        config.loggingFlags &= ~Logging.STATE;

        log.push("\n%s", config.toString());

        this.builder = ppl.createIncrementalBuilder(config);
        this.builder.addListener(this);

        log.push("Builder started");
    }
    void returnErrors(Request req) {

    }
    /**
     *  ?prefix=&module=&line=&column=
     *
     *  returns:
     *  {
     *      "suggestions" : [
     *          {
     *              "name" : "",        //
     *              "type" : "",        // eg. int
     *              "parent" : ""       // eg. StructName
     *          }
     *      ]
     *  }
     */
    string returnSuggestions(Request req) {

        string prefix  = req.getDecodedQueryValue("prefix");
        string module_ = req.getDecodedQueryValue("module");
        int line       = req.getQueryIntValue("line", -1);
        int column     = req.getQueryIntValue("column", -1);

        log.push("suggestions requested for module %s [%s:%s] prefix=%s", module_, line, column, prefix);

        JSONValue[] suggestions;

        if(prefix.length > 0 && module_.length > 0) {

            Module* ptr = module_ in resolvedModules;
            if(!ptr) {
                ptr = module_ in parsedModules;
            }
            if(ptr) {
                Module m = *ptr;
                log.push("Inspecting module %s%s", m, m.isResolved ? " (resolved)" : "");

                string[] prefixes = prefix.split(".");
                log.push("prefixes = %s", prefixes);
                assert(prefixes.length>0);

                auto position = Position(line, column);

                Container con = m.getContainerAtPosition(position);
                if(con is null) {
                    log.push("\tNo container found");
                } else {


                    if(con.isFunction()) {
                        auto scope_ = con.as!LiteralFunction.getFunction;
                        log.push("\tFunction %s", scope_.name);

                        auto node = scope_.findNearestTo(position);
                        log.push("\tNearest node = %s", node);

                        // find class/struct/tuple/enum
                        log.push("Looking for target %s", prefixes[0]);
                        auto varOrFunc = m.idTargetFinder.find(prefixes[0], node);
                        if(varOrFunc) {
                            Variable var  = varOrFunc.as!Variable;
                            Function func = varOrFunc.as!Function;

                            if(var) {
                                log.push("\tVariable found: %s", var);

                                // Add members to list of suggestions

                                auto struct_ = var.getType.getStruct();
                                auto array = var.getType().getArrayType();
                                auto tuple_ = var.getType().getTuple();


                                if(struct_) {

                                    foreach(v; struct_.getMemberVariables()) {
                                        JSONValue suggest = [
                                            "name"   : v.name,
                                            "kind"   : "memberVariable",
                                            "type"   : "%s".format(v.type),
                                            "public" : v.access.isPublic ? "true" : "false"
                                        ];
                                        suggestions ~= suggest;
                                    }
                                    foreach(v; struct_.getStaticVariables()) {
                                        JSONValue suggest = [
                                            "name"   : v.name,
                                            "kind"   : "staticVariable",
                                            "type"   : "%s".format(v.type),
                                            "public" : v.access.isPublic ? "true" : "false"
                                        ];
                                        suggestions ~= suggest;
                                    }
                                    foreach(f; struct_.getMemberFunctions()) {

                                        // private function has been removed :(

                                        if(f.name=="new") {
                                            // Handle new?
                                            continue;
                                        }

                                        auto type = f.getType().getFunctionType();

                                        JSONValue[] params;

                                        foreach(p; f.params().getParams()) {

                                            // Handle implicit this* ?

                                            JSONValue param = [ "name" : p.name, "type" : "%s".format(p.getType()) ];
                                            params ~= param;
                                        }

                                        JSONValue suggest = [
                                            "name"       : f.name,
                                            "kind"       : "memberFunction",
                                            "returnType" : "%s".format(type.returnType()),
                                            "public"     : f.access.isPublic ? "true" : "false"
                                        ];
                                        suggest["params"] = params;
                                        suggestions ~= suggest;
                                    }

                                }

                            } else {
                                log.push("\tFunction found: %s", func);
                            }
                        }

                    } else if(con.isModule()) {
                        log.push("\tModule");


                    } else if(con.isTuple()) {
                        log.push("\tTuple");


                    } else {
                        // Struct or Class
                        auto struct_ = con.as!Struct;
                        log.push("\tStruct or Class %s", struct_.name);


                    }
                }

                // Find the nearest node
                // auto stmts = m.getStatementsOnLine(line);
                // log.push("Found %s statements on line %s", stmts.length, line);
                // foreach(stmt; stmts) {
                //     log.push("\t%s", stmt);
                // }


                // m.resolver.resolveIdentifier(prefix)


                // TypeFinder

                // FunctionFinder

                // ImportFinder

                // IdentifierTargetFinder  find(name, node)

            }
        }



        JSONValue json = [ "suggestions" : suggestions ];

        return json.toString();
    }
}
