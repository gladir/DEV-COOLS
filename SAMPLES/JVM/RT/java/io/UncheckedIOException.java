package java.io;
import java.lang.RuntimeException;
public class UncheckedIOException extends RuntimeException {
    public UncheckedIOException(String message, IOException cause) { super(message, cause); }
    public UncheckedIOException(IOException cause) { super(cause); }
}
