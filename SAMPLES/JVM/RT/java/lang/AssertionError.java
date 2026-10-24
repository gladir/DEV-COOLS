package java.lang;
public class AssertionError extends Error {
    public AssertionError() { }
    public AssertionError(Object detail) { super(String.valueOf(detail)); if (detail instanceof Throwable) initCause((Throwable) detail); }
    public AssertionError(String message, Throwable cause) { super(message, cause); }
    public AssertionError(boolean d) { super(String.valueOf(d)); }
    public AssertionError(char d) { super(String.valueOf(d)); }
    public AssertionError(int d) { super(String.valueOf(d)); }
    public AssertionError(long d) { super(String.valueOf(d)); }
    public AssertionError(double d) { super(String.valueOf(d)); }
}
