package java.util;
import java.lang.RuntimeException;
public class NoSuchElementException extends RuntimeException {
    public NoSuchElementException() { super(); }
    public NoSuchElementException(String s) { super(s); }
    public NoSuchElementException(String s, Throwable cause) { super(s, cause); }
    public NoSuchElementException(Throwable cause) { super(cause); }
}
