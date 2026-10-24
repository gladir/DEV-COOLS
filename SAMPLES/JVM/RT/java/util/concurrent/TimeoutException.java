package java.util.concurrent;
import java.lang.Exception;
public class TimeoutException extends Exception {
    private static final long serialVersionUID = 1900926677490660714L;
    public TimeoutException() { super(); }
    public TimeoutException(String s) { super(s); }
    public TimeoutException(String s, Throwable cause) { super(s, cause); }
    public TimeoutException(Throwable cause) { super(cause); }
}
