package java.lang;
public class NoSuchMethodException extends ReflectiveOperationException {
    private static final long serialVersionUID = 5034388446362600923L;
    public NoSuchMethodException() { super(); }
    public NoSuchMethodException(String s) { super(s); }
    public NoSuchMethodException(String s, Throwable cause) { super(s, cause); }
    public NoSuchMethodException(Throwable cause) { super(cause); }
}
