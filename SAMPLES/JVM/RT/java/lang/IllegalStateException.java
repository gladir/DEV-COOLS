package java.lang;
public class IllegalStateException extends RuntimeException {
    private static final long serialVersionUID = -1848914673093119416L;
    public IllegalStateException() { super(); }
    public IllegalStateException(String s) { super(s); }
    public IllegalStateException(String s, Throwable cause) { super(s, cause); }
    public IllegalStateException(Throwable cause) { super(cause); }
}
