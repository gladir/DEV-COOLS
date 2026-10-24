package java.util;
import java.lang.RuntimeException;
public class ConcurrentModificationException extends RuntimeException {
    private static final long serialVersionUID = -3666751008965953603L;
    public ConcurrentModificationException() { super(); }
    public ConcurrentModificationException(String s) { super(s); }
    public ConcurrentModificationException(String s, Throwable cause) { super(s, cause); }
    public ConcurrentModificationException(Throwable cause) { super(cause); }
}
