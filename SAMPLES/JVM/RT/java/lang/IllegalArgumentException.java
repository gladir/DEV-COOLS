package java.lang;
public class IllegalArgumentException extends RuntimeException {
    private static final long serialVersionUID = -5365630128856068164L;
    public IllegalArgumentException() { super(); }
    public IllegalArgumentException(String s) { super(s); }
    public IllegalArgumentException(String s, Throwable cause) { super(s, cause); }
    public IllegalArgumentException(Throwable cause) { super(cause); }
}
