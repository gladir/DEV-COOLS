package java.time;
import java.time.temporal.*;
import java.time.format.*;
public final class LocalTime implements Temporal, Comparable<LocalTime> {
    public static final LocalTime MIDNIGHT = new LocalTime(0, 0, 0, 0), MIN = MIDNIGHT, NOON = new LocalTime(12, 0, 0, 0), MAX = new LocalTime(23, 59, 59, 999999999);
    private final int hour, minute, second, nano;
    private LocalTime(int h, int m, int s, int n) { hour = h; minute = m; second = s; nano = n; }
    public static LocalTime of(int h, int m) { return of(h, m, 0, 0); }
    public static LocalTime of(int h, int m, int s) { return of(h, m, s, 0); }
    public static LocalTime of(int h, int m, int s, int n) {
        if (h < 0 || h > 23) throw new DateTimeException("Invalid value for HourOfDay (valid values 0 - 23): " + h);
        if (m < 0 || m > 59) throw new DateTimeException("Invalid value for MinuteOfHour (valid values 0 - 59): " + m);
        if (s < 0 || s > 59) throw new DateTimeException("Invalid value for SecondOfMinute (valid values 0 - 59): " + s);
        return new LocalTime(h, m, s, n);
    }
    public static LocalTime ofSecondOfDay(long s) { return new LocalTime((int) (s / 3600), (int) (s / 60 % 60), (int) (s % 60), 0); }
    public static LocalTime ofNanoOfDay(long n) { long s = n / 1000000000L; return new LocalTime((int) (s / 3600), (int) (s / 60 % 60), (int) (s % 60), (int) (n % 1000000000L)); }
    public static LocalTime now() { long ms = System.currentTimeMillis(); return ofNanoOfDay(Math.floorMod(ms, 86400000L) * 1000000L); }
    public static LocalTime parse(CharSequence t) {
        String s = t.toString();
        try {
            String[] p = s.split(":");
            int sec = 0, nano = 0;
            if (p.length > 2) { String[] q = p[2].split("\\."); sec = Integer.parseInt(q[0]); if (q.length > 1) { String f = (q[1] + "000000000").substring(0, 9); nano = Integer.parseInt(f); } }
            return of(Integer.parseInt(p[0]), Integer.parseInt(p[1]), sec, nano);
        } catch (RuntimeException e) { throw new DateTimeParseException("Text '" + s + "' could not be parsed at index 0", s, 0); }
    }
    public static LocalTime parse(CharSequence t, DateTimeFormatter f) { return f.parseTime(t.toString()); }
    public int getHour() { return hour; }
    public int getMinute() { return minute; }
    public int getSecond() { return second; }
    public int getNano() { return nano; }
    public int toSecondOfDay() { return hour * 3600 + minute * 60 + second; }
    public long toNanoOfDay() { return toSecondOfDay() * 1000000000L + nano; }
    public LocalTime plusHours(long h) { return plusNanos0((h % 24) * 3600000000000L); }
    public LocalTime plusMinutes(long m) { return plusNanos0((m % 1440) * 60000000000L); }
    public LocalTime plusSeconds(long s) { return plusNanos0((s % 86400) * 1000000000L); }
    public LocalTime plusNanos(long n) { return plusNanos0(n % 86400000000000L); }
    public LocalTime minusHours(long h) { return plusHours(-(h % 24)); }
    public LocalTime minusMinutes(long m) { return plusMinutes(-(m % 1440)); }
    public LocalTime minusSeconds(long s) { return plusSeconds(-(s % 86400)); }
    private LocalTime plusNanos0(long n) { return ofNanoOfDay(Math.floorMod(toNanoOfDay() + n, 86400000000000L)); }
    public LocalTime plus(Duration d) { return plusNanos0(d.toNanos() % 86400000000000L); }
    public LocalTime minus(Duration d) { return plusNanos0(-(d.toNanos() % 86400000000000L)); }
    public LocalTime withHour(int h) { return of(h, minute, second, nano); }
    public LocalTime withMinute(int m) { return of(hour, m, second, nano); }
    public LocalTime withSecond(int s) { return of(hour, minute, s, nano); }
    public LocalTime withNano(int n) { return of(hour, minute, second, n); }
    public LocalTime truncatedTo(ChronoUnit u) { return ofNanoOfDay(toNanoOfDay() / u.getDuration().toNanos() * u.getDuration().toNanos()); }
    public boolean isBefore(LocalTime o) { return compareTo(o) < 0; }
    public boolean isAfter(LocalTime o) { return compareTo(o) > 0; }
    public int compareTo(LocalTime o) { return Long.compare(toNanoOfDay(), o.toNanoOfDay()); }
    public LocalDateTime atDate(LocalDate d) { return LocalDateTime.of(d, this); }
    public String format(DateTimeFormatter f) { return f.format(this); }
    public boolean equals(Object o) { return o instanceof LocalTime t && t.toNanoOfDay() == toNanoOfDay(); }
    public int hashCode() { return Long.hashCode(toNanoOfDay()); }
    public String toString() {
        StringBuilder buf = new StringBuilder(18);
        buf.append(hour < 10 ? "0" : "").append(hour).append(minute < 10 ? ":0" : ":").append(minute);
        if (second > 0 || nano > 0) {
            buf.append(second < 10 ? ":0" : ":").append(second);
            if (nano > 0) {
                buf.append('.');
                if (nano % 1000000 == 0) buf.append(Integer.toString((nano / 1000000) + 1000).substring(1));
                else if (nano % 1000 == 0) buf.append(Integer.toString((nano / 1000) + 1000000).substring(1));
                else buf.append(Integer.toString((nano) + 1000000000).substring(1));
            }
        }
        return buf.toString();
    }
}
