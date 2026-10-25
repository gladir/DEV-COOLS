package java.lang.reflect;
public class UndeclaredThrowableException extends RuntimeException {
    private static final long serialVersionUID = 330127114055056639L;
    private Throwable undeclaredThrowable;
    public UndeclaredThrowableException(Throwable undeclaredThrowable) { super((Throwable) null); this.undeclaredThrowable = undeclaredThrowable; }
    public UndeclaredThrowableException(Throwable undeclaredThrowable, String s) { super(s, null); this.undeclaredThrowable = undeclaredThrowable; }
    public Throwable getUndeclaredThrowable() { return undeclaredThrowable; }
    public Throwable getCause() { return undeclaredThrowable; }
}
