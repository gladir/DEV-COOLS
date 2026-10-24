package java.io;
public class FileInputStream extends InputStream {
    private final int fd;
    private int h = -1;
    public FileInputStream(int fd) { this.fd = fd; }
    public FileInputStream(String name) throws FileNotFoundException {
        this.fd = -1;
        if (FS.isDir(name)) throw new FileNotFoundException(name + " (Is a directory)");
        h = FS.open(name, 0);
        if (h < 0) throw new FileNotFoundException(name + " (No such file or directory)");
    }
    public FileInputStream(File f) throws FileNotFoundException { this(f.getPath()); }
    public int read() throws IOException {
        if (fd == 0) return java.lang.VM.readByte();
        if (h < 0) throw new IOException("Stream Closed");
        return FS.read(h);
    }
    public int read(byte[] b, int off, int len) throws IOException {
        if (off < 0 || len < 0 || len > b.length - off) throw new IndexOutOfBoundsException();
        if (len == 0) return 0;
        if (fd == 0) {
            int c = java.lang.VM.readByte();
            if (c < 0) return -1;
            b[off] = (byte) c;
            int i = 1;
            while (c != '\n' && i < len) {
                c = java.lang.VM.readByte();
                if (c < 0) break;
                b[off + i++] = (byte) c;
            }
            return i;
        }
        if (h < 0) throw new IOException("Stream Closed");
        return FS.readBytes(h, b, off, len);
    }
    public long skip(long n) throws IOException {
        if (fd == 0 || h < 0) return super.skip(n);
        long p = FS.pos(h), sz = FS.size(h);
        long k = Math.max(0, Math.min(n, sz - p));
        FS.seek(h, p + k);
        return k;
    }
    public int available() throws IOException {
        if (h < 0) return 0;
        long r = FS.size(h) - FS.pos(h);
        return r > Integer.MAX_VALUE ? Integer.MAX_VALUE : (int) r;
    }
    public void close() throws IOException { if (h >= 0) { FS.close(h); h = -1; } }
}
