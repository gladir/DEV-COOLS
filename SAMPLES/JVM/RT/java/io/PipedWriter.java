package java.io;
public class PipedWriter extends Writer {
    private PipedReader sink;
    public PipedWriter(PipedReader snk) throws IOException { connect(snk); }
    public PipedWriter() { }
    public synchronized void connect(PipedReader snk) throws IOException {
        if (snk == null) throw new NullPointerException();
        else if (sink != null || snk.connected) throw new IOException("Already connected");
        sink = snk;
        snk.in = -1;
        snk.out = 0;
        snk.connected = true;
    }
    public void write(int c) throws IOException {
        if (sink == null) throw new IOException("Pipe not connected");
        sink.receive(c);
    }
    public void write(char[] cbuf, int off, int len) throws IOException {
        if (sink == null) throw new IOException("Pipe not connected");
        sink.receive(cbuf, off, len);
    }
    public synchronized void flush() throws IOException {
        if (sink != null) { synchronized (sink) { sink.notifyAll(); } }
    }
    public void close() throws IOException { if (sink != null) sink.receivedLast(); }
}
