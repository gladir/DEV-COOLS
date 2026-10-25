package java.lang;
public class ExceptionInInitializerError extends LinkageError {
    private static final long serialVersionUID = 1521711792217232256L;
    public ExceptionInInitializerError() { super(); }
    public ExceptionInInitializerError(Throwable thrown) { super(null, thrown); }
    public ExceptionInInitializerError(String s) { super(s); }
    public Throwable getException() { return getCause(); }
}
