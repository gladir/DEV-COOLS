package java.lang;
public class EnumConstantNotPresentException extends RuntimeException {
    public EnumConstantNotPresentException() { super(); }
    public EnumConstantNotPresentException(String s) { super(s); }
    public EnumConstantNotPresentException(String s, Throwable cause) { super(s, cause); }
    public EnumConstantNotPresentException(Throwable cause) { super(cause); }
}
