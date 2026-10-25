package java.io;
public class CharArrayReader extends Reader {
    protected char[] buf;
    protected int pos, markedPos = 0, count;
    public CharArrayReader(char[] buf) { this.buf = buf; this.pos = 0; this.count = buf.length; }
    public CharArrayReader(char[] buf, int offset, int length) {
        this.buf = buf; this.pos = offset; this.count = Math.min(offset + length, buf.length); this.markedPos = offset;
    }
    public int read() throws IOException {
        if (pos >= count) return -1;
        return buf[pos++];
    }
    public int read(char[] cbuf, int off, int len) throws IOException {
        if (pos >= count) return -1;
        int avail = count - pos;
        if (len > avail) len = avail;
        if (len <= 0) return 0;
        System.arraycopy(buf, pos, cbuf, off, len);
        pos += len;
        return len;
    }
    public long skip(long n) throws IOException {
        long avail = count - pos;
        if (n > avail) n = avail;
        if (n < 0) return 0;
        pos += (int) n;
        return n;
    }
    public boolean ready() throws IOException { return (count - pos) > 0; }
    public boolean markSupported() { return true; }
    public void mark(int readAheadLimit) throws IOException { markedPos = pos; }
    public void reset() throws IOException { pos = markedPos; }
    public void close() { buf = null; }
}
