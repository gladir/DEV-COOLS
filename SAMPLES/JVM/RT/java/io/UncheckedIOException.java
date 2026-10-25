package java.io;
import java.lang.RuntimeException;
public class UncheckedIOException extends RuntimeException {
    private static final long serialVersionUID = -8134305061645241065L;
    public UncheckedIOException(String message, IOException cause) { super(message, cause); }
    public UncheckedIOException(IOException cause) { super(cause); }
}
