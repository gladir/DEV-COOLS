package java.io;
public class PushbackReader extends FilterReader {
    private char[] buf;
    private int pos;
    public PushbackReader(Reader in, int size) {
        super(in);
        if (size <= 0) throw new IllegalArgumentException("size <= 0");
        this.buf = new char[size];
        this.pos = size;
    }
    public PushbackReader(Reader in) { this(in, 1); }
    public int read() throws IOException {
        if (pos < buf.length) return buf[pos++];
        return super.read();
    }
    public int read(char[] cbuf, int off, int len) throws IOException {
        if (len == 0) return 0;
        int avail = buf.length - pos;
        if (avail > 0) {
            if (len < avail) avail = len;
            System.arraycopy(buf, pos, cbuf, off, avail);
            pos += avail;
            off += avail;
            len -= avail;
        }
        if (len > 0) {
            len = super.read(cbuf, off, len);
            if (len == -1) return (avail == 0) ? -1 : avail;
            return avail + len;
        }
        return avail;
    }
    public void unread(int c) throws IOException {
        if (pos == 0) throw new IOException("Pushback buffer overflow");
        buf[--pos] = (char) c;
    }
    public void unread(char[] cbuf, int off, int len) throws IOException {
        if (len > pos) throw new IOException("Pushback buffer overflow");
        pos -= len;
        System.arraycopy(cbuf, off, buf, pos, len);
    }
    public void unread(char[] cbuf) throws IOException { unread(cbuf, 0, cbuf.length); }
    public boolean ready() throws IOException { return (pos < buf.length) || super.ready(); }
    public boolean markSupported() { return false; }
    public void mark(int readAheadLimit) throws IOException { throw new IOException("mark/reset not supported"); }
    public void reset() throws IOException { throw new IOException("mark/reset not supported"); }
}
