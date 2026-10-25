package java.lang;
public class IllegalMonitorStateException extends RuntimeException {
    private static final long serialVersionUID = 3713306369498869069L;
    public IllegalMonitorStateException() { super(); }
    public IllegalMonitorStateException(String s) { super(s); }
    public IllegalMonitorStateException(String s, Throwable cause) { super(s, cause); }
    public IllegalMonitorStateException(Throwable cause) { super(cause); }
}
