package java.lang;
public class SecurityException extends RuntimeException {
    private static final long serialVersionUID = 6878364983674394167L;
    public SecurityException() { super(); }
    public SecurityException(String s) { super(s); }
    public SecurityException(String s, Throwable cause) { super(s, cause); }
    public SecurityException(Throwable cause) { super(cause); }
}
