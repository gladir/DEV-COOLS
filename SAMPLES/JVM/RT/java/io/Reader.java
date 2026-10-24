package java.io;
public abstract class Reader implements Readable, Closeable {
    protected Reader() {}
    public int read() throws IOException { char[] c = new char[1]; return read(c, 0, 1) == -1 ? -1 : c[0]; }
    public int read(char[] c) throws IOException { return read(c, 0, c.length); }
    public abstract int read(char[] c, int off, int len) throws IOException;
    public boolean ready() throws IOException { return false; }
    public long skip(long n) throws IOException { long k = 0; while (k < n && read() != -1) k++; return k; }
    public abstract void close() throws IOException;
}
