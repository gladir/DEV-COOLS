package java.io;
import java.lang.Exception;
public class IOException extends Exception {
    public IOException() { super(); }
    public IOException(String s) { super(s); }
    public IOException(String s, Throwable cause) { super(s, cause); }
    public IOException(Throwable cause) { super(cause); }
}
