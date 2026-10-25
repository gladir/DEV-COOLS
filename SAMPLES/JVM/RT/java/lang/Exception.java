package java.lang;
public class Exception extends Throwable {
    private static final long serialVersionUID = -3387516993124229948L;
    public Exception() { super(); }
    public Exception(String s) { super(s); }
    public Exception(String s, Throwable cause) { super(s, cause); }
    public Exception(Throwable cause) { super(cause); }
    protected Exception(String message, Throwable cause, boolean enableSuppression, boolean writableStackTrace) { super(message, cause, enableSuppression, writableStackTrace); }
}
