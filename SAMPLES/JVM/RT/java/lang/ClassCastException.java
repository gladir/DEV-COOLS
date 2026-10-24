package java.lang;
public class ClassCastException extends RuntimeException {
    private static final long serialVersionUID = -9223365651070458532L;
    public ClassCastException() { super(); }
    public ClassCastException(String s) { super(s); }
    public ClassCastException(String s, Throwable cause) { super(s, cause); }
    public ClassCastException(Throwable cause) { super(cause); }
}
