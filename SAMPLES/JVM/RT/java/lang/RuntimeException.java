package java.lang;
public class RuntimeException extends Exception {
    private static final long serialVersionUID = -7034897190745766939L;
    public RuntimeException() { super(); }
    public RuntimeException(String s) { super(s); }
    public RuntimeException(String s, Throwable cause) { super(s, cause); }
    public RuntimeException(Throwable cause) { super(cause); }
    protected RuntimeException(String message, Throwable cause, boolean enableSuppression, boolean writableStackTrace) { super(message, cause, enableSuppression, writableStackTrace); }
}
