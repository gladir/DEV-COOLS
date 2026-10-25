package java.io;
public class FileNotFoundException extends IOException {
    private static final long serialVersionUID = -897856973823710492L;
    public FileNotFoundException() { super(); }
    public FileNotFoundException(String s) { super(s); }
    public FileNotFoundException(String s, Throwable cause) { super(s, cause); }
    public FileNotFoundException(Throwable cause) { super(cause); }
}
