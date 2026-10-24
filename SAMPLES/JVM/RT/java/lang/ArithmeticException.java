package java.lang;
public class ArithmeticException extends RuntimeException {
    private static final long serialVersionUID = 2256477558314496007L;
    public ArithmeticException() { super(); }
    public ArithmeticException(String s) { super(s); }
    public ArithmeticException(String s, Throwable cause) { super(s, cause); }
    public ArithmeticException(Throwable cause) { super(cause); }
}
