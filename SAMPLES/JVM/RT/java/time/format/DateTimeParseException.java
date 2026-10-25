package java.time.format;
public class DateTimeParseException extends java.time.DateTimeException {
    private static final long serialVersionUID = 4304633501674722597L;
    private final String parsed;
    public DateTimeParseException(String message, CharSequence parsedData, int errorIndex) { super(message); parsed = parsedData.toString(); }
    public String getParsedString() { return parsed; }
}
