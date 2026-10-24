package java.util;
public class TimeZone {
    private final String id;
    private TimeZone(String id) { this.id = id; }
    public static TimeZone getDefault() { return new TimeZone("UTC"); }
    public static TimeZone getTimeZone(String id) { return new TimeZone(id); }
    public String getID() { return id; }
    public int getRawOffset() { return 0; }
}
