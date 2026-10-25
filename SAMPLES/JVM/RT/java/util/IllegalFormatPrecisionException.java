package java.util;
public class IllegalFormatPrecisionException extends IllegalFormatException {
    private static final long serialVersionUID = 18711008L;
    private int p;
    public IllegalFormatPrecisionException(int p) { this.p = p; }
    public String getMessage() { return Integer.toString(p); }
}
