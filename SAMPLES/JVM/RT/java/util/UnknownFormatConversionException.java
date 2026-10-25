package java.util;
public class UnknownFormatConversionException extends IllegalFormatException {
    private static final long serialVersionUID = 19060418L;
    private String s;
    public UnknownFormatConversionException(String s) { this.s = s; }
    public String getConversion() { return s; }
    public String getMessage() { return String.format("Conversion = '%s'", s); }
}
