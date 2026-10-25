package java.io;
public abstract class Reader implements Readable, Closeable {
    protected Object lock;
    protected Reader() { this.lock = this; }
    protected Reader(Object lock) { this.lock = lock; }
    public int read() throws IOException { char[] c = new char[1]; return read(c, 0, 1) == -1 ? -1 : c[0]; }
    public int read(char[] c) throws IOException { return read(c, 0, c.length); }
    public abstract int read(char[] c, int off, int len) throws IOException;
    public boolean ready() throws IOException { return false; }
    public long skip(long n) throws IOException {
        if (n < 0L) throw new IllegalArgumentException("skip value is negative");
        long k = 0;
        while (k < n && read() != -1) k++;
        return k;
    }
    public boolean markSupported() { return false; }
    public void mark(int readAheadLimit) throws IOException { throw new IOException("mark() not supported"); }
    public void reset() throws IOException { throw new IOException("reset() not supported"); }
    public abstract void close() throws IOException;
    public long transferTo(Writer out) throws IOException {
        long transferred = 0;
        char[] buffer = new char[8192];
        int nRead;
        while ((nRead = read(buffer, 0, 8192)) >= 0) {
            out.write(buffer, 0, nRead);
            transferred += nRead;
        }
        return transferred;
    }
    public static Reader nullReader() {
        return new Reader() {
            public int read(char[] c, int off, int len) { return -1; }
            public void close() { }
        };
    }
}
