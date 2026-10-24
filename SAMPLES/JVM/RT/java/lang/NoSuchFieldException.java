package java.lang;
public class NoSuchFieldException extends ReflectiveOperationException {
    public NoSuchFieldException() { super(); }
    public NoSuchFieldException(String s) { super(s); }
    public NoSuchFieldException(String s, Throwable cause) { super(s, cause); }
    public NoSuchFieldException(Throwable cause) { super(cause); }
}
