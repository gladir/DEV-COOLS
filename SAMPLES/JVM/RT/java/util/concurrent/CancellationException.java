package java.util.concurrent;
import java.lang.IllegalStateException;
public class CancellationException extends IllegalStateException {
    public CancellationException() { super(); }
    public CancellationException(String s) { super(s); }
    public CancellationException(String s, Throwable cause) { super(s, cause); }
    public CancellationException(Throwable cause) { super(cause); }
}
