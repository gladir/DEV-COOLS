package java.io;
import java.lang.Exception;
public class IOException extends Exception {
    private static final long serialVersionUID = 7818375828146090155L;
    public IOException() { super(); }
    public IOException(String s) { super(s); }
    public IOException(String s, Throwable cause) { super(s, cause); }
    public IOException(Throwable cause) { super(cause); }
}
