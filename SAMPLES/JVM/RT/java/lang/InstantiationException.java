package java.lang;
public class InstantiationException extends ReflectiveOperationException {
    public InstantiationException() { super(); }
    public InstantiationException(String s) { super(s); }
    public InstantiationException(String s, Throwable cause) { super(s, cause); }
    public InstantiationException(Throwable cause) { super(cause); }
}
