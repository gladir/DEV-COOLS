package java.lang;
public class InstantiationException extends ReflectiveOperationException {
    private static final long serialVersionUID = -8441929162975509110L;
    public InstantiationException() { super(); }
    public InstantiationException(String s) { super(s); }
    public InstantiationException(String s, Throwable cause) { super(s, cause); }
    public InstantiationException(Throwable cause) { super(cause); }
}
