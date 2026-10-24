package java.lang;
public class BootstrapMethodError extends LinkageError {
    public BootstrapMethodError() { super(); }
    public BootstrapMethodError(String s) { super(s); }
    public BootstrapMethodError(String s, Throwable cause) { super(s, cause); }
    public BootstrapMethodError(Throwable cause) { super(cause == null ? null : cause.toString()); initCause(cause); }
}
