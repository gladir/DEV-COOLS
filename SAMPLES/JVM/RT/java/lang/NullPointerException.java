package java.lang;
public class NullPointerException extends RuntimeException {
    private static final long serialVersionUID = 5162710183389028792L;
    public NullPointerException() { super(); }
    public NullPointerException(String s) { super(s); }
    public NullPointerException(String s, Throwable cause) { super(s, cause); }
    public NullPointerException(Throwable cause) { super(cause); }
}
