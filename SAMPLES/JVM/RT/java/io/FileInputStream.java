package java.io;
public class FileInputStream extends InputStream {
    private final int fd;
    public FileInputStream(int fd) { this.fd = fd; }
    public int read() throws IOException { return java.lang.VM.readByte(); }
    public int available() throws IOException { return 0; }
}
