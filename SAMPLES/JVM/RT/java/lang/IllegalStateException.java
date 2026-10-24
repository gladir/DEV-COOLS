package java.lang;
public class IllegalStateException extends RuntimeException {
    public IllegalStateException() { super(); }
    public IllegalStateException(String s) { super(s); }
    public IllegalStateException(String s, Throwable cause) { super(s, cause); }
    public IllegalStateException(Throwable cause) { super(cause); }
}
