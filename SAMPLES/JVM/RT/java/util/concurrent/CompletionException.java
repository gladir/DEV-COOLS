package java.util.concurrent;
import java.lang.RuntimeException;
public class CompletionException extends RuntimeException {
    private static final long serialVersionUID = 7830266012832686185L;
    public CompletionException() { super(); }
    public CompletionException(String s) { super(s); }
    public CompletionException(String s, Throwable cause) { super(s, cause); }
    public CompletionException(Throwable cause) { super(cause); }
}
