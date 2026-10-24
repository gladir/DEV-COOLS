package java.util.concurrent;
import java.lang.Exception;
public class ExecutionException extends Exception {
    public ExecutionException() { super(); }
    public ExecutionException(String s) { super(s); }
    public ExecutionException(String s, Throwable cause) { super(s, cause); }
    public ExecutionException(Throwable cause) { super(cause); }
}
