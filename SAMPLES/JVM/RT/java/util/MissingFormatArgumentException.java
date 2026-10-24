package java.util;
public class MissingFormatArgumentException extends IllegalFormatException {
    private String s;
    public MissingFormatArgumentException(String s) { this.s = s; }
    public String getFormatSpecifier() { return s; }
    public String getMessage() { return "Format specifier '" + s + "'"; }
}
