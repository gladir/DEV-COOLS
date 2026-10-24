package java.text;
public class ParseException extends Exception {
    private final int errorOffset;
    public ParseException(String s, int errorOffset) { super(s); this.errorOffset = errorOffset; }
    public int getErrorOffset() { return errorOffset; }
}
