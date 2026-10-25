package java.lang;
public class IndexOutOfBoundsException extends RuntimeException {
    private static final long serialVersionUID = 234122996006267687L;
    public IndexOutOfBoundsException() { super(); }
    public IndexOutOfBoundsException(String s) { super(s); }
    public IndexOutOfBoundsException(int index) { super("Index out of range: " + index); }
    public IndexOutOfBoundsException(long index) { super("Index out of range: " + index); }
}
