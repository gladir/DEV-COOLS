package java.util.zip;
import java.io.*;
public class InflaterInputStream extends FilterInputStream {
    protected Inflater inf;
    protected byte[] buf;
    protected int len;
    private boolean closed;
    private boolean reachEOF;
    boolean usesDefaultInflater = false;
    private int chunk = 512;
    public InflaterInputStream(InputStream in, Inflater inf, int size) {
        super(in);
        if (in == null || inf == null) throw new NullPointerException();
        else if (size <= 0) throw new IllegalArgumentException("buffer size <= 0");
        this.inf = inf;
        buf = new byte[size];
    }
    public InflaterInputStream(InputStream in, Inflater inf) { this(in, inf, 512); }
    public InflaterInputStream(InputStream in) { this(in, new Inflater()); usesDefaultInflater = true; }
    private void ensureOpen() throws IOException { if (closed) throw new IOException("Stream closed"); }
    public int read() throws IOException {
        ensureOpen();
        byte[] single = new byte[1];
        return read(single, 0, 1) == -1 ? -1 : single[0] & 0xff;
    }
    public int read(byte[] b, int off, int len) throws IOException {
        ensureOpen();
        if (b == null) throw new NullPointerException();
        else if (off < 0 || len < 0 || len > b.length - off) throw new IndexOutOfBoundsException();
        else if (len == 0) return 0;
        try {
            int n;
            while ((n = inf.inflate(b, off, len)) == 0) {
                if (inf.finished() || inf.needsDictionary()) { reachEOF = true; return -1; }
                if (inf.needsInput()) fill();
            }
            return n;
        } catch (DataFormatException e) {
            String s = e.getMessage();
            throw new ZipException(s != null ? s : "Invalid ZLIB data format");
        }
    }
    public int available() throws IOException { ensureOpen(); return reachEOF ? 0 : 1; }
    public long skip(long n) throws IOException {
        if (n < 0) throw new IllegalArgumentException("negative skip length");
        ensureOpen();
        int max = (int) Math.min(n, Integer.MAX_VALUE);
        int total = 0;
        byte[] b = new byte[Math.min(max, 512)];
        while (total < max) {
            int len = max - total;
            if (len > b.length) len = b.length;
            len = read(b, 0, len);
            if (len == -1) { reachEOF = true; break; }
            total += len;
        }
        return total;
    }
    public void close() throws IOException {
        if (!closed) { in.close(); closed = true; }
    }
    protected void fill() throws IOException {
        ensureOpen();
        if (chunk > buf.length) buf = new byte[chunk];
        len = in.read(buf, 0, buf.length);
        if (len == -1) throw new EOFException("Unexpected end of ZLIB input stream");
        inf.setInput(buf, 0, len);
        if (chunk < (1 << 20)) chunk *= 2;
    }
    public boolean markSupported() { return false; }
    public void mark(int readlimit) { }
    public void reset() throws IOException { throw new IOException("mark/reset not supported"); }
}
