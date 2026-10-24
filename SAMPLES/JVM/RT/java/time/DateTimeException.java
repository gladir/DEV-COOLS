package java.time;
import java.lang.RuntimeException;
public class DateTimeException extends RuntimeException {
    public DateTimeException() { super(); }
    public DateTimeException(String s) { super(s); }
    public DateTimeException(String s, Throwable cause) { super(s, cause); }
    public DateTimeException(Throwable cause) { super(cause); }
}
