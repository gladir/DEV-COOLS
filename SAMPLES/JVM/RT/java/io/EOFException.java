package java.io;
public class EOFException extends IOException {
    private static final long serialVersionUID = 6433858223774886977L;
    public EOFException() { super(); }
    public EOFException(String s) { super(s); }
    public EOFException(String s, Throwable cause) { super(s, cause); }
    public EOFException(Throwable cause) { super(cause); }
}
