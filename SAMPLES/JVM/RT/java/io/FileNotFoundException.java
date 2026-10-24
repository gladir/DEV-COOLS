package java.io;
public class FileNotFoundException extends IOException {
    public FileNotFoundException() { super(); }
    public FileNotFoundException(String s) { super(s); }
    public FileNotFoundException(String s, Throwable cause) { super(s, cause); }
    public FileNotFoundException(Throwable cause) { super(cause); }
}
