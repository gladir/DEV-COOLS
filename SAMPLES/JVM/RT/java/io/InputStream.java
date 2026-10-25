package java.io;
public abstract class InputStream implements Closeable {
    public InputStream() {}
    public abstract int read() throws IOException;
    public int read(byte[] b) throws IOException { return read(b, 0, b.length); }
    public int read(byte[] b, int off, int len) throws IOException {
        if (off < 0 || len < 0 || len > b.length - off) throw new IndexOutOfBoundsException("Range [" + off + ", " + off + " + " + len + ") out of bounds for length " + b.length);
        if (len == 0) return 0;
        int c = read();
        if (c == -1) return -1;
        b[off] = (byte) c;
        int i = 1;
        try {
            for (; i < len; i++) {
                c = read();
                if (c == -1) break;
                b[off + i] = (byte) c;
            }
        } catch (IOException ee) { }
        return i;
    }
    public byte[] readAllBytes() throws IOException { return readNBytes(Integer.MAX_VALUE); }
    public byte[] readNBytes(int len) throws IOException {
        if (len < 0) throw new IllegalArgumentException("len < 0");
        ByteArrayOutputStream bo = new ByteArrayOutputStream();
        byte[] buf = new byte[8192];
        int remaining = len;
        while (remaining > 0) {
            int n = read(buf, 0, Math.min(buf.length, remaining));
            if (n < 0) break;
            bo.write(buf, 0, n);
            remaining -= n;
        }
        return bo.toByteArray();
    }
    public int readNBytes(byte[] b, int off, int len) throws IOException {
        int n = 0;
        while (n < len) {
            int count = read(b, off + n, len - n);
            if (count < 0) break;
            n += count;
        }
        return n;
    }
    public long skip(long n) throws IOException {
        long remaining = n;
        if (n <= 0) return 0;
        byte[] skipBuffer = new byte[(int) Math.min(2048, remaining)];
        while (remaining > 0) {
            int nr = read(skipBuffer, 0, (int) Math.min(skipBuffer.length, remaining));
            if (nr < 0) break;
            remaining -= nr;
        }
        return n - remaining;
    }
    public void skipNBytes(long n) throws IOException {
        while (n > 0) {
            long ns = skip(n);
            if (ns > 0 && ns <= n) n -= ns;
            else if (ns == 0) {
                if (read() == -1) throw new EOFException();
                n--;
            } else throw new IOException("Unable to skip exactly");
        }
    }
    public int available() throws IOException { return 0; }
    public void close() throws IOException { }
    public void mark(int readlimit) { }
    public void reset() throws IOException { throw new IOException("mark/reset not supported"); }
    public boolean markSupported() { return false; }
    public long transferTo(OutputStream out) throws IOException {
        long transferred = 0;
        byte[] buffer = new byte[8192];
        int read;
        while ((read = this.read(buffer, 0, 8192)) >= 0) {
            out.write(buffer, 0, read);
            transferred += read;
        }
        return transferred;
    }
    public static InputStream nullInputStream() {
        return new InputStream() {
            public int read() { return -1; }
            public int available() { return 0; }
        };
    }
}
