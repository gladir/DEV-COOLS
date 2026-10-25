package java.lang;
public class MatchException extends RuntimeException {
    public MatchException() { super(); }
    public MatchException(String s) { super(s); }
    public MatchException(String s, Throwable cause) { super(s, cause); }
    public MatchException(Throwable cause) { super(cause); }
}
