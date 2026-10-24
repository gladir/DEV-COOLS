package java.time;
public final class Year {
    private final int year;
    private Year(int y) { year = y; }
    public static Year of(int y) { return new Year(y); }
    public static Year now() { return new Year(LocalDate.now().getYear()); }
    public static boolean isLeap(long y) { return ((y & 3) == 0) && ((y % 100) != 0 || (y % 400) == 0); }
    public boolean isLeap() { return isLeap(year); }
    public int getValue() { return year; }
    public int length() { return isLeap() ? 366 : 365; }
    public String toString() { return Integer.toString(year); }
}
