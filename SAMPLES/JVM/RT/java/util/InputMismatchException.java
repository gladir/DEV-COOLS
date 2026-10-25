package java.util;
public class InputMismatchException extends NoSuchElementException {
    private static final long serialVersionUID = 8811230760997066428L;
    public InputMismatchException() { super(); }
    public InputMismatchException(String s) { super(s); }
    public InputMismatchException(String s, Throwable cause) { super(s, cause); }
    public InputMismatchException(Throwable cause) { super(cause); }
}
