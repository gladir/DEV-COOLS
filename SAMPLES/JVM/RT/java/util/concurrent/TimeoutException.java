package java.util.concurrent;
import java.lang.Exception;
public class TimeoutException extends Exception {
    public TimeoutException() { super(); }
    public TimeoutException(String s) { super(s); }
    public TimeoutException(String s, Throwable cause) { super(s, cause); }
    public TimeoutException(Throwable cause) { super(cause); }
}
