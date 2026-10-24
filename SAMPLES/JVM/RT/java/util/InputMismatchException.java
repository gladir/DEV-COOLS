package java.util;
public class InputMismatchException extends NoSuchElementException {
    public InputMismatchException() { super(); }
    public InputMismatchException(String s) { super(s); }
    public InputMismatchException(String s, Throwable cause) { super(s, cause); }
    public InputMismatchException(Throwable cause) { super(cause); }
}
