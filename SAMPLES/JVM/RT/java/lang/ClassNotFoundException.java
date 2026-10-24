package java.lang;
public class ClassNotFoundException extends ReflectiveOperationException {
    public ClassNotFoundException() { super(); }
    public ClassNotFoundException(String s) { super(s); }
    public ClassNotFoundException(String s, Throwable cause) { super(s, cause); }
    public ClassNotFoundException(Throwable cause) { super(cause); }
}
