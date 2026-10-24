package java.lang;
public class TypeNotPresentException extends RuntimeException {
    public TypeNotPresentException() { super(); }
    public TypeNotPresentException(String s) { super(s); }
    public TypeNotPresentException(String s, Throwable cause) { super(s, cause); }
    public TypeNotPresentException(Throwable cause) { super(cause); }
}
