package java.text;
import java.util.*;
public abstract class DateFormat extends Format {
    public static final int FULL = 0, LONG = 1, MEDIUM = 2, SHORT = 3, DEFAULT = 2;
    public abstract String format(Date d);
    public abstract Date parse(String s) throws ParseException;
    String formatObject(Object o) { return format((Date) o); }
    public static DateFormat getDateInstance() { return new SimpleDateFormat("MMM d, yyyy"); }
    public static DateFormat getDateInstance(int style) { return new SimpleDateFormat(style == SHORT ? "M/d/yy" : "MMM d, yyyy"); }
    public static DateFormat getDateInstance(int style, Locale l) { return getDateInstance(style); }
    public static DateFormat getTimeInstance() { return new SimpleDateFormat("h:mm:ss a"); }
    public static DateFormat getDateTimeInstance() { return new SimpleDateFormat("MMM d, yyyy, h:mm:ss a"); }
    public void setLenient(boolean b) { }
}
