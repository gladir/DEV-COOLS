package java.lang;
public class ClassNotFoundException extends ReflectiveOperationException {
    private static final long serialVersionUID = 9176873029745254542L;
    public ClassNotFoundException() { super(); }
    public ClassNotFoundException(String s) { super(s); }
    public ClassNotFoundException(String s, Throwable cause) { super(s, cause); }
    public ClassNotFoundException(Throwable cause) { super(cause); }
}
