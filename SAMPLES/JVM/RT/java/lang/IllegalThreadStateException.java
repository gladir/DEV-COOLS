package java.lang;
public class IllegalThreadStateException extends IllegalArgumentException {
    private static final long serialVersionUID = -7626246362397460174L;
    public IllegalThreadStateException() { super(); }
    public IllegalThreadStateException(String s) { super(s); }
    public IllegalThreadStateException(String s, Throwable cause) { super(s, cause); }
    public IllegalThreadStateException(Throwable cause) { super(cause); }
}
