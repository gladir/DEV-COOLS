package java.util;
import java.lang.RuntimeException;
public class NoSuchElementException extends RuntimeException {
    private static final long serialVersionUID = 6769829250639411880L;
    public NoSuchElementException() { super(); }
    public NoSuchElementException(String s) { super(s); }
    public NoSuchElementException(String s, Throwable cause) { super(s, cause); }
    public NoSuchElementException(Throwable cause) { super(cause); }
}
