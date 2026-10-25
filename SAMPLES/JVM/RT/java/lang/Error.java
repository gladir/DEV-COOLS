package java.lang;
public class Error extends Throwable {
    private static final long serialVersionUID = 4980196508277280342L;
    public Error() { super(); }
    public Error(String s) { super(s); }
    public Error(String s, Throwable cause) { super(s, cause); }
    public Error(Throwable cause) { super(cause); }
}
