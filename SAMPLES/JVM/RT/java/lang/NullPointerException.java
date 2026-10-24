package java.lang;
public class NullPointerException extends RuntimeException {
    public NullPointerException() { super(); }
    public NullPointerException(String s) { super(s); }
    public NullPointerException(String s, Throwable cause) { super(s, cause); }
    public NullPointerException(Throwable cause) { super(cause); }
}
