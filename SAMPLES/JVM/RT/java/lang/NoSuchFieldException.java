package java.lang;
public class NoSuchFieldException extends ReflectiveOperationException {
    private static final long serialVersionUID = -6143714805279938260L;
    public NoSuchFieldException() { super(); }
    public NoSuchFieldException(String s) { super(s); }
    public NoSuchFieldException(String s, Throwable cause) { super(s, cause); }
    public NoSuchFieldException(Throwable cause) { super(cause); }
}
