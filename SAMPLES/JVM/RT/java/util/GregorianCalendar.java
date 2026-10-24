package java.util;
public class GregorianCalendar extends Calendar {
    public GregorianCalendar() { time = System.currentTimeMillis(); }
    public GregorianCalendar(int y, int m, int d) { set(YEAR, y); set(MONTH, m); set(DAY_OF_MONTH, d); }
    public GregorianCalendar(int y, int m, int d, int h, int mi) { this(y, m, d); set(HOUR_OF_DAY, h); set(MINUTE, mi); }
    public GregorianCalendar(int y, int m, int d, int h, int mi, int s) { this(y, m, d, h, mi); set(SECOND, s); }
    public boolean isLeapYear(int y) { return java.time.Year.isLeap(y); }
}
