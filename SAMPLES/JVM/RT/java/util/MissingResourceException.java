package java.util;
import java.lang.RuntimeException;
public class MissingResourceException extends RuntimeException {
    public MissingResourceException() { super(); }
    public MissingResourceException(String s) { super(s); }
    public MissingResourceException(String s, Throwable cause) { super(s, cause); }
    public MissingResourceException(Throwable cause) { super(cause); }
}
