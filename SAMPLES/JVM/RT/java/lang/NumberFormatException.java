package java.lang;
public class NumberFormatException extends IllegalArgumentException {
    public NumberFormatException() { super(); }
    public NumberFormatException(String s) { super(s); }
    public NumberFormatException(String s, Throwable cause) { super(s, cause); }
    public NumberFormatException(Throwable cause) { super(cause); }
}
