package java.util;
public class Date implements java.io.Serializable, Cloneable, Comparable<Date> {
    private long time;
    public Date() { this(System.currentTimeMillis()); }
    public Date(long date) { time = date; }
    @SuppressWarnings("deprecation")
    public Date(int year, int month, int date) { this(new GregorianCalendar(year + 1900, month, date).getTimeInMillis()); }
    public long getTime() { return time; }
    public void setTime(long t) { time = t; }
    public boolean before(Date w) { return time < w.time; }
    public boolean after(Date w) { return time > w.time; }
    public boolean equals(Object o) { return o instanceof Date d && d.time == time; }
    public int compareTo(Date o) { return Long.compare(time, o.time); }
    public int hashCode() { return (int) time ^ (int) (time >> 32); }
    public Object clone() { return new Date(time); }
    public java.time.Instant toInstant() { return java.time.Instant.ofEpochMilli(time); }
    public static Date from(java.time.Instant i) { return new Date(i.toEpochMilli()); }
    public String toString() {
        java.time.LocalDateTime t = java.time.LocalDateTime.ofEpochSecond(Math.floorDiv(time, 1000L), 0);
        return t.getDayOfWeek().getDisplayName(java.time.format.TextStyle.SHORT, Locale.US) + " " + t.getMonth().getDisplayName(java.time.format.TextStyle.SHORT, Locale.US) + " "
            + (t.getDayOfMonth() < 10 ? "0" : "") + t.getDayOfMonth() + " " + (t.getHour() < 10 ? "0" : "") + t.getHour() + ":" + (t.getMinute() < 10 ? "0" : "") + t.getMinute() + ":" + (t.getSecond() < 10 ? "0" : "") + t.getSecond() + " UTC " + t.getYear();
    }
}
