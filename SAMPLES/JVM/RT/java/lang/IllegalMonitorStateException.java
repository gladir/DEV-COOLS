package java.lang;
public class IllegalMonitorStateException extends RuntimeException {
    public IllegalMonitorStateException() { super(); }
    public IllegalMonitorStateException(String s) { super(s); }
    public IllegalMonitorStateException(String s, Throwable cause) { super(s, cause); }
    public IllegalMonitorStateException(Throwable cause) { super(cause); }
}
