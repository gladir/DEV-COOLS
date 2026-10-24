package java.lang;
public class Error extends Throwable {
    public Error() { super(); }
    public Error(String s) { super(s); }
    public Error(String s, Throwable cause) { super(s, cause); }
    public Error(Throwable cause) { super(cause); }
}
