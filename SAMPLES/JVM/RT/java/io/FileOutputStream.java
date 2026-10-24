package java.io;
public class FileOutputStream extends OutputStream {
    private final int fd;
    public FileOutputStream(int fd) { this.fd = fd; }
    public void write(int b) throws IOException { VMio.writeByte(fd, b); }
    public void flush() throws IOException { }
    int fdNumber() { return fd; }
}
