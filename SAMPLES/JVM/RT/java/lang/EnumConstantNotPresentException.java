package java.lang;
public class EnumConstantNotPresentException extends RuntimeException {
    private static final long serialVersionUID = -6046998521960521108L;
    public EnumConstantNotPresentException() { super(); }
    public EnumConstantNotPresentException(String s) { super(s); }
    public EnumConstantNotPresentException(String s, Throwable cause) { super(s, cause); }
    public EnumConstantNotPresentException(Throwable cause) { super(cause); }
}
