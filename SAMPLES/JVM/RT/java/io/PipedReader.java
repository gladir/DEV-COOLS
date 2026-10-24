package java.io;
public class PipedReader extends Reader {
    boolean closedByWriter = false;
    boolean closedByReader = false;
    boolean connected = false;
    Thread readSide;
    Thread writeSide;
    private static final int DEFAULT_PIPE_SIZE = 1024;
    char[] buffer;
    int in = -1;
    int out = 0;
    public PipedReader(PipedWriter src) throws IOException { this(src, DEFAULT_PIPE_SIZE); }
    public PipedReader(PipedWriter src, int pipeSize) throws IOException { buffer = new char[pipeSize]; connect(src); }
    public PipedReader() { buffer = new char[DEFAULT_PIPE_SIZE]; }
    public PipedReader(int pipeSize) { buffer = new char[pipeSize]; }
    public void connect(PipedWriter src) throws IOException { src.connect(this); }
    synchronized void receive(int c) throws IOException {
        if (!connected) throw new IOException("Pipe not connected");
        else if (closedByWriter || closedByReader) throw new IOException("Pipe closed");
        writeSide = Thread.currentThread();
        while (in == out) {
            notifyAll();
            try { wait(1000); } catch (InterruptedException ex) { throw new InterruptedIOException(); }
        }
        if (in < 0) { in = 0; out = 0; }
        buffer[in++] = (char) c;
        if (in >= buffer.length) in = 0;
    }
    synchronized void receive(char[] c, int off, int len) throws IOException {
        while (--len >= 0) receive(c[off++]);
    }
    synchronized void receivedLast() { closedByWriter = true; notifyAll(); }
    public synchronized int read() throws IOException {
        if (!connected) throw new IOException("Pipe not connected");
        else if (closedByReader) throw new IOException("Pipe closed");
        readSide = Thread.currentThread();
        while (in < 0) {
            if (closedByWriter) return -1;
            notifyAll();
            try { wait(1000); } catch (InterruptedException ex) { throw new InterruptedIOException(); }
        }
        int ret = buffer[out++];
        if (out >= buffer.length) out = 0;
        if (in == out) in = -1;
        return ret;
    }
    public synchronized int read(char[] cbuf, int off, int len) throws IOException {
        if (len == 0) return 0;
        int c = read();
        if (c < 0) return -1;
        cbuf[off] = (char) c;
        int rlen = 1;
        while ((in >= 0) && (--len > 0)) {
            cbuf[off + rlen] = buffer[out++];
            rlen++;
            if (out >= buffer.length) out = 0;
            if (in == out) in = -1;
        }
        return rlen;
    }
    public synchronized boolean ready() throws IOException { return in >= 0; }
    public void close() throws IOException { in = -1; closedByReader = true; }
}
