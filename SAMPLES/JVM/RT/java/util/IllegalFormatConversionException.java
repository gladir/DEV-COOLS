package java.util;
public class IllegalFormatConversionException extends IllegalFormatException {
    private static final long serialVersionUID = 17000126L;
    private char c;
    private Class<?> arg;
    public IllegalFormatConversionException(char c, Class<?> arg) { this.c = c; this.arg = arg; }
    public String getMessage() { return c + " != " + arg.getName(); }
}
