package java.lang;
public class NegativeArraySizeException extends RuntimeException {
    private static final long serialVersionUID = -8960118058596991861L;
    public NegativeArraySizeException() { super(); }
    public NegativeArraySizeException(String s) { super(s); }
    public NegativeArraySizeException(String s, Throwable cause) { super(s, cause); }
    public NegativeArraySizeException(Throwable cause) { super(cause); }
}
