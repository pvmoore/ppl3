module server;
/**
 *  Runs a server socket that listens on a port. Provides the following:
 *
 *  - Compile project
 *  - Provide json errors
 *  - Provide suggestions
 */
import ppl;
import std.stdio : writefln;
import std.socket;
import std.algorithm.iteration : filter;
import std.range : array;
import std.format : format;
import common : From;

void main(string[] argv) {

    ushort port  = 8080;

    auto server = new Server(port);

    server.startIncrementalBuilder(["directory":""]);

    server.startListening();



}

struct Request {
    string method;
    string path;
    string protocol;
    string[string] query;
    string[string] headers;
    string content;

    string toString() {
        return "[Request %s %s %s ?%s (content = %s chars)]".format(method, protocol, path, query, content.length);
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

    Module[] modules;
public:
    this(ushort port) {
        this.port = port;
    }
    void startListening() {
        listener = new TcpSocket();
        listener.blocking = true;
        listener.bind(new InternetAddress(port));
        listener.listen(10);

        socketSet = new SocketSet();

        writefln("Server listening on localhost:%s ...", port);

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
        writefln("...buildFinished");

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
    void handle(Socket socket) {

        string content = readAll(socket);
        //writefln("content = %s", content);

        Request req = decodeRequest(content);
        writefln("%s", req);

        string response;

        switch(req.path) {
            case "/quit":
                shutdown();
                break;
            case "/watch":
                startIncrementalBuilder(req.query);
                break;
            case "/problems":
                returnErrors();
                break;
            case "/suggestions":
                returnSuggestions(req.query);
                break;
            default:
                break;
        }

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


        //writefln("headers = %s", r.headers);

        //writefln("%s", r.toString());

        return r;
    }
    /**
     *  ?directory=
     */
    void startIncrementalBuilder(string[string] query) {

        // Stop any existing builder
        if(this.builder) {
            this.builder.shutdown();
        }

        string directory  = query["directory"];

        directory = "\\pvmoore\\d\\apps\\ppl3\\projects\\test\\";

        if(false==From!"std.file".exists(directory)) {
            writefln("directory '%s' does not exist", directory);
            return;
        }

        string configFile = directory ~ "config.toml";
        writefln("Reading config from %s", configFile);

        auto ppl = PPL3.instance();

        auto config = new ConfigReader(configFile).read();
        config.writeASM = false;
        config.writeOBJ = false;
        config.writeAST = false;
        config.writeIR  = false;
        config.writeJSON = false;

        writefln("\n%s", config.toString());

        this.builder = ppl.createIncrementalBuilder(config);
        this.builder.addListener(this);

    }
    void returnErrors() {

    }
    /**
     *  ?prefix=&module=&line=&column=
     */
    void returnSuggestions(string[string] query) {

    }
}
