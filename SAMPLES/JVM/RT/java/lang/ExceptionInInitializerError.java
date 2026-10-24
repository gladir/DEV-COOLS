package java.lang;
public class ExceptionInInitializerError extends LinkageError {
    public ExceptionInInitializerError() { super(); }
    public ExceptionInInitializerError(Throwable thrown) { super(null, thrown); }
    public ExceptionInInitializerError(String s) { super(s); }
    public Throwable getException() { return getCause(); }
}
