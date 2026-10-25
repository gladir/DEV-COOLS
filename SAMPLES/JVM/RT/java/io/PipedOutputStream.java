package java.io;
public class PipedOutputStream extends OutputStream {
    private volatile PipedInputStream sink;
    public PipedOutputStream(PipedInputStream snk) throws IOException { connect(snk); }
    public PipedOutputStream() { }
    public synchronized void connect(PipedInputStream snk) throws IOException {
        if (snk == null) throw new NullPointerException();
        else if (sink != null || snk.connected) throw new IOException("Already connected");
        sink = snk;
        snk.in = -1;
        snk.out = 0;
        snk.connected = true;
    }
    public void write(int b) throws IOException {
        PipedInputStream sink = this.sink;
        if (sink == null) throw new IOException("Pipe not connected");
        sink.receive(b);
    }
    public void write(byte[] b, int off, int len) throws IOException {
        PipedInputStream sink = this.sink;
        if (sink == null) throw new IOException("Pipe not connected");
        else if (b == null) throw new NullPointerException();
        else if ((off < 0) || (off > b.length) || (len < 0) || ((off + len) > b.length) || ((off + len) < 0)) throw new IndexOutOfBoundsException();
        else if (len == 0) return;
        sink.receive(b, off, len);
    }
    public synchronized void flush() throws IOException {
        if (sink != null) { synchronized (sink) { sink.notifyAll(); } }
    }
    public void close() throws IOException {
        PipedInputStream sink = this.sink;
        if (sink != null) sink.receivedLast();
    }
}
