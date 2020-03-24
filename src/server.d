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

void main(string[] argv) {

    ushort port  = 8080;

    auto server = new Server(port);
    server.startListening();

}

struct Request {
    string method;
    string path;
    string protocol;
    string query;
    string[string] headers;
    string content;

    string toString() {
        return "[Request %s %s %s ?%s (content = %s chars)]".format(method, protocol, path, query, content.length);
    }
}

final class Server {
private:
    ushort port;
    TcpSocket listener;
    SocketSet socketSet;
    Socket[] clients;
    bool isRunning = true;
    IncrementalBuilder builder;
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
                // ?directory=
                startIncrementalBuilder(req.query);
                break;
            case "/problems":
                returnErrors();
                break;
            case "/suggestions":
                // ?module=&line=&column=
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
            r.query = r.path[q+1..$];
            r.path = r.path[0..q];
        } else {
            r.query = "";
        }

        foreach(i, l; lines[1..$]) {
            //writefln("line = %s", l);
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
    void startIncrementalBuilder(string query) {

    }
    void returnErrors() {

    }
    void returnSuggestions(string query) {

    }
}
