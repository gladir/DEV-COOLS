package java.io;
public class PushbackInputStream extends FilterInputStream {
    protected byte[] buf;
    protected int pos;
    public PushbackInputStream(InputStream in, int size) {
        super(in);
        if (size <= 0) throw new IllegalArgumentException("size <= 0");
        this.buf = new byte[size];
        this.pos = size;
    }
    public PushbackInputStream(InputStream in) { this(in, 1); }
    public int read() throws IOException {
        if (pos < buf.length) return buf[pos++] & 0xff;
        return super.read();
    }
    public int read(byte[] b, int off, int len) throws IOException {
        if (len == 0) return 0;
        int avail = buf.length - pos;
        if (avail > 0) {
            if (len < avail) avail = len;
            System.arraycopy(buf, pos, b, off, avail);
            pos += avail;
            off += avail;
            len -= avail;
        }
        if (len > 0) {
            len = super.read(b, off, len);
            if (len == -1) return avail == 0 ? -1 : avail;
            return avail + len;
        }
        return avail;
    }
    public void unread(int b) throws IOException {
        if (pos == 0) throw new IOException("Push back buffer is full");
        buf[--pos] = (byte) b;
    }
    public void unread(byte[] b, int off, int len) throws IOException {
        if (len > pos) throw new IOException("Push back buffer is full");
        pos -= len;
        System.arraycopy(b, off, buf, pos, len);
    }
    public void unread(byte[] b) throws IOException { unread(b, 0, b.length); }
    public int available() throws IOException { return (buf.length - pos) + super.available(); }
    public boolean markSupported() { return false; }
    public synchronized void mark(int readlimit) { }
    public synchronized void reset() throws IOException { throw new IOException("mark/reset not supported"); }
}
