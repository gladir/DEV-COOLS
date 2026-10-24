package java.lang;
public class SecurityException extends RuntimeException {
    public SecurityException() { super(); }
    public SecurityException(String s) { super(s); }
    public SecurityException(String s, Throwable cause) { super(s, cause); }
    public SecurityException(Throwable cause) { super(cause); }
}
