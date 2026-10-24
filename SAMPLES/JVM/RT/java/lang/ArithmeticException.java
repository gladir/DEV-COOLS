package java.lang;
public class ArithmeticException extends RuntimeException {
    public ArithmeticException() { super(); }
    public ArithmeticException(String s) { super(s); }
    public ArithmeticException(String s, Throwable cause) { super(s, cause); }
    public ArithmeticException(Throwable cause) { super(cause); }
}
