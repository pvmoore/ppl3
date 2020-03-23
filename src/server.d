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

void main(string[] argv) {

    ushort port  = 8080;

    auto server = new Server(port);
    server.startListening();

}

struct Request {
    string path;
    string query;
    string fragment;
    string[string] headers;
    string content;
}

final class Server {
private:
    ushort port;
    TcpSocket listener;
    SocketSet socketSet;
    Socket[] clients;
    bool isRunning = true;
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
    private void handle(Socket socket) {

        string content = readAll(socket);
        writefln("content = %s", content);

        Request req = decodeRequest(content);


        socket.send("HTTP/1.1 200 OK\r\n");
        socket.send("Connection: closed\r\n");
        socket.send("Content-type: text/plain\r\n");
        socket.send("Content-length: 10\r\n");
        socket.send("0123456789\r\n");

        socket.shutdown(SocketShutdown.BOTH);
        socket.close();
    }
    private string readAll(Socket socket) {
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
    private Request decodeRequest(string text) {
        Request r;

        // todo

        return r;
    }
}
