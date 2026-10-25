package java.io;
public class FileOutputStream extends OutputStream {
    private final int fd;
    private int h = -1;
    public FileOutputStream(int fd) { this.fd = fd; }
    public FileOutputStream(String name) throws FileNotFoundException { this(name, false); }
    public FileOutputStream(File f) throws FileNotFoundException { this(f.getPath(), false); }
    public FileOutputStream(File f, boolean append) throws FileNotFoundException { this(f.getPath(), append); }
    public FileOutputStream(String name, boolean append) throws FileNotFoundException {
        this.fd = -1;
        h = FS.open(name, append ? 2 : 1);
        if (h < 0) throw new FileNotFoundException(name + " (No such file or directory)");
    }
    public void write(int b) throws IOException {
        if (fd >= 0) { VMio.writeByte(fd, b); return; }
        if (h < 0) throw new IOException("Stream Closed");
        FS.write(h, new byte[] { (byte) b }, 0, 1);
    }
    public void write(byte[] b, int off, int len) throws IOException {
        if (fd >= 0) { for (int i = 0; i < len; i++) VMio.writeByte(fd, b[off + i]); return; }
        if (h < 0) throw new IOException("Stream Closed");
        FS.write(h, b, off, len);
    }
    public void flush() throws IOException { }
    public void close() throws IOException { if (h >= 0) { FS.close(h); h = -1; } }
    int fdNumber() { return fd; }
}
