package java.lang;
public class StringIndexOutOfBoundsException extends IndexOutOfBoundsException {
    private static final long serialVersionUID = -6762910422159637258L;
    public StringIndexOutOfBoundsException() { super(); }
    public StringIndexOutOfBoundsException(String s) { super(s); }
    public StringIndexOutOfBoundsException(int index) { super("Index out of range: " + index); }
}
