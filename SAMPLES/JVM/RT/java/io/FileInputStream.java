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
        if (fd == 0) return super.read(b, off, len);
        if (h < 0) throw new IOException("Stream Closed");
        return FS.readBytes(h, b, off, len);
    }
    public int available() throws IOException { return 0; }
    public void close() throws IOException { if (h >= 0) { FS.close(h); h = -1; } }
}
