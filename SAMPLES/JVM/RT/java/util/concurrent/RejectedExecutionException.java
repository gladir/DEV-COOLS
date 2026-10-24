package java.util.concurrent;
import java.lang.RuntimeException;
public class RejectedExecutionException extends RuntimeException {
    public RejectedExecutionException() { super(); }
    public RejectedExecutionException(String s) { super(s); }
    public RejectedExecutionException(String s, Throwable cause) { super(s, cause); }
    public RejectedExecutionException(Throwable cause) { super(cause); }
}
