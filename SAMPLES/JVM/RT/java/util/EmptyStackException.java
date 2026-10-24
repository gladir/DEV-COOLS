package java.util;
import java.lang.RuntimeException;
public class EmptyStackException extends RuntimeException {
    private static final long serialVersionUID = 5084686378493302095L;
    public EmptyStackException() { super(); }
    public EmptyStackException(String s) { super(s); }
    public EmptyStackException(String s, Throwable cause) { super(s, cause); }
    public EmptyStackException(Throwable cause) { super(cause); }
}
