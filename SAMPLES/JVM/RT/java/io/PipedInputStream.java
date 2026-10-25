package java.io;
public class PipedInputStream extends InputStream {
    boolean closedByWriter = false;
    volatile boolean closedByReader = false;
    boolean connected = false;
    Thread readSide;
    Thread writeSide;
    protected static final int PIPE_SIZE = 1024;
    protected byte[] buffer;
    protected int in = -1;
    protected int out = 0;
    public PipedInputStream(PipedOutputStream src) throws IOException { this(src, PIPE_SIZE); }
    public PipedInputStream(PipedOutputStream src, int pipeSize) throws IOException { initPipe(pipeSize); connect(src); }
    public PipedInputStream() { initPipe(PIPE_SIZE); }
    public PipedInputStream(int pipeSize) { initPipe(pipeSize); }
    private void initPipe(int pipeSize) {
        if (pipeSize <= 0) throw new IllegalArgumentException("Pipe Size <= 0");
        buffer = new byte[pipeSize];
    }
    public void connect(PipedOutputStream src) throws IOException { src.connect(this); }
    protected synchronized void receive(int b) throws IOException {
        checkStateForReceive();
        writeSide = Thread.currentThread();
        if (in == out) awaitSpace();
        if (in < 0) { in = 0; out = 0; }
        buffer[in++] = (byte) (b & 0xFF);
        if (in >= buffer.length) in = 0;
    }
    synchronized void receive(byte[] b, int off, int len) throws IOException {
        checkStateForReceive();
        writeSide = Thread.currentThread();
        int bytesToTransfer = len;
        while (bytesToTransfer > 0) {
            if (in == out) awaitSpace();
            int nextTransferAmount = 0;
            if (out < in) nextTransferAmount = buffer.length - in;
            else if (in < out) {
                if (in == -1) { in = out = 0; nextTransferAmount = buffer.length - in; }
                else nextTransferAmount = out - in;
            }
            if (nextTransferAmount > bytesToTransfer) nextTransferAmount = bytesToTransfer;
            System.arraycopy(b, off, buffer, in, nextTransferAmount);
            bytesToTransfer -= nextTransferAmount;
            off += nextTransferAmount;
            in += nextTransferAmount;
            if (in >= buffer.length) in = 0;
        }
    }
    private void checkStateForReceive() throws IOException {
        if (!connected) throw new IOException("Pipe not connected");
        else if (closedByWriter || closedByReader) throw new IOException("Pipe closed");
        else if (readSide != null && !readSide.isAlive()) throw new IOException("Read end dead");
    }
    private void awaitSpace() throws IOException {
        while (in == out) {
            checkStateForReceive();
            notifyAll();
            try { wait(1000); } catch (InterruptedException ex) { throw new InterruptedIOException(); }
        }
    }
    synchronized void receivedLast() { closedByWriter = true; notifyAll(); }
    public synchronized int read() throws IOException {
        if (!connected) throw new IOException("Pipe not connected");
        else if (closedByReader) throw new IOException("Pipe closed");
        else if (writeSide != null && !writeSide.isAlive() && !closedByWriter && (in < 0)) throw new IOException("Write end dead");
        readSide = Thread.currentThread();
        int trials = 2;
        while (in < 0) {
            if (closedByWriter) return -1;
            if ((writeSide != null) && (!writeSide.isAlive()) && (--trials < 0)) throw new IOException("Pipe broken");
            notifyAll();
            try { wait(1000); } catch (InterruptedException ex) { throw new InterruptedIOException(); }
        }
        int ret = buffer[out++] & 0xFF;
        if (out >= buffer.length) out = 0;
        if (in == out) in = -1;
        return ret;
    }
    public synchronized int read(byte[] b, int off, int len) throws IOException {
        if (len == 0) return 0;
        int c = read();
        if (c < 0) return -1;
        b[off] = (byte) c;
        int rlen = 1;
        while ((in >= 0) && (len > 1)) {
            int available;
            if (in > out) available = Math.min((buffer.length - out), (in - out));
            else available = buffer.length - out;
            if (available > (len - 1)) available = len - 1;
            System.arraycopy(buffer, out, b, off + rlen, available);
            out += available;
            rlen += available;
            len -= available;
            if (out >= buffer.length) out = 0;
            if (in == out) in = -1;
        }
        return rlen;
    }
    public synchronized int available() throws IOException {
        if (in < 0) return 0;
        else if (in == out) return buffer.length;
        else if (in > out) return in - out;
        else return in + buffer.length - out;
    }
    public void close() throws IOException {
        closedByReader = true;
        synchronized (this) { in = -1; }
    }
}
