package java.time;
import java.time.temporal.*;
import java.time.format.*;
public final class LocalDateTime implements Temporal, Comparable<LocalDateTime>, java.io.Serializable {
    private Object writeReplace() { return new Ser(Ser.LOCAL_DATE_TIME_TYPE, this); }
    private void readObject(java.io.ObjectInputStream s) throws java.io.InvalidObjectException { throw new java.io.InvalidObjectException("Deserialization via serialization delegate"); }
    void writeExternal(java.io.DataOutput out) throws java.io.IOException { date.writeExternal(out); time.writeExternal(out); }
    static LocalDateTime readExternal(java.io.DataInput in) throws java.io.IOException { LocalDate date = LocalDate.readExternal(in); LocalTime time = LocalTime.readExternal(in); return LocalDateTime.of(date, time); }
    private static final long serialVersionUID = 6207766400415563566L;
    private final LocalDate date;
    private final LocalTime time;
    private LocalDateTime(LocalDate d, LocalTime t) { date = d; time = t; }
    public static LocalDateTime of(LocalDate d, LocalTime t) { return new LocalDateTime(d, t); }
    public static LocalDateTime of(int y, int mo, int d, int h, int mi) { return new LocalDateTime(LocalDate.of(y, mo, d), LocalTime.of(h, mi)); }
    public static LocalDateTime of(int y, int mo, int d, int h, int mi, int s) { return new LocalDateTime(LocalDate.of(y, mo, d), LocalTime.of(h, mi, s)); }
    public static LocalDateTime of(int y, int mo, int d, int h, int mi, int s, int n) { return new LocalDateTime(LocalDate.of(y, mo, d), LocalTime.of(h, mi, s, n)); }
    public static LocalDateTime of(int y, Month mo, int d, int h, int mi) { return of(y, mo.getValue(), d, h, mi); }
    public static LocalDateTime of(int y, Month mo, int d, int h, int mi, int s) { return of(y, mo.getValue(), d, h, mi, s); }
    public static LocalDateTime now() { return ofEpochSecond(Math.floorDiv(System.currentTimeMillis(), 1000L), (int) Math.floorMod(System.currentTimeMillis(), 1000L) * 1000000); }
    public static LocalDateTime ofEpochSecond(long s, int nano) {
        long days = Math.floorDiv(s, 86400L);
        long sod = Math.floorMod(s, 86400L);
        return new LocalDateTime(LocalDate.ofEpochDay(days), LocalTime.ofNanoOfDay(sod * 1000000000L + nano));
    }
    public static LocalDateTime parse(CharSequence text) {
        String s = text.toString();
        int t = s.indexOf('T');
        if (t < 0) throw new DateTimeParseException("Text '" + s + "' could not be parsed at index " + Math.min(10, s.length()), s, 0);
        return new LocalDateTime(LocalDate.parse(s.substring(0, t)), LocalTime.parse(s.substring(t + 1)));
    }
    public static LocalDateTime parse(CharSequence text, DateTimeFormatter f) { return f.parseDateTime(text.toString()); }
    public LocalDate toLocalDate() { return date; }
    public LocalTime toLocalTime() { return time; }
    public long toEpochDay() { return date.toEpochDay(); }
    public int getYear() { return date.getYear(); }
    public int getMonthValue() { return date.getMonthValue(); }
    public Month getMonth() { return date.getMonth(); }
    public int getDayOfMonth() { return date.getDayOfMonth(); }
    public int getDayOfYear() { return date.getDayOfYear(); }
    public DayOfWeek getDayOfWeek() { return date.getDayOfWeek(); }
    public int getHour() { return time.getHour(); }
    public int getMinute() { return time.getMinute(); }
    public int getSecond() { return time.getSecond(); }
    public int getNano() { return time.getNano(); }
    private LocalDateTime plusNanosTotal(long deltaNanos) {
        long total = date.toEpochDay() * 86400000000000L + time.toNanoOfDay() + deltaNanos;
        long days = Math.floorDiv(total, 86400000000000L);
        return new LocalDateTime(LocalDate.ofEpochDay(days), LocalTime.ofNanoOfDay(Math.floorMod(total, 86400000000000L)));
    }
    public LocalDateTime plusDays(long d) { return new LocalDateTime(date.plusDays(d), time); }
    public LocalDateTime plusWeeks(long w) { return new LocalDateTime(date.plusWeeks(w), time); }
    public LocalDateTime plusMonths(long m) { return new LocalDateTime(date.plusMonths(m), time); }
    public LocalDateTime plusYears(long y) { return new LocalDateTime(date.plusYears(y), time); }
    public LocalDateTime plusHours(long h) { return plusNanosTotal(h * 3600000000000L); }
    public LocalDateTime plusMinutes(long m) { return plusNanosTotal(m * 60000000000L); }
    public LocalDateTime plusSeconds(long s) { return plusNanosTotal(s * 1000000000L); }
    public LocalDateTime plusNanos(long n) { return plusNanosTotal(n); }
    public LocalDateTime minusDays(long d) { return plusDays(-d); }
    public LocalDateTime minusWeeks(long w) { return plusWeeks(-w); }
    public LocalDateTime minusMonths(long m) { return plusMonths(-m); }
    public LocalDateTime minusYears(long y) { return plusYears(-y); }
    public LocalDateTime minusHours(long h) { return plusHours(-h); }
    public LocalDateTime minusMinutes(long m) { return plusMinutes(-m); }
    public LocalDateTime minusSeconds(long s) { return plusSeconds(-s); }
    public LocalDateTime plus(Duration d) { return plusNanosTotal(d.toNanos()); }
    public LocalDateTime minus(Duration d) { return plusNanosTotal(-d.toNanos()); }
    public LocalDateTime plus(long amount, TemporalUnit u) {
        ChronoUnit c = (ChronoUnit) u;
        if (c.ordinal() >= ChronoUnit.DAYS.ordinal()) return new LocalDateTime(date.plus(amount, u), time);
        return plusNanosTotal(amount * c.getDuration().toNanos());
    }
    public LocalDateTime withHour(int h) { return new LocalDateTime(date, time.withHour(h)); }
    public LocalDateTime withMinute(int m) { return new LocalDateTime(date, time.withMinute(m)); }
    public LocalDateTime withSecond(int s) { return new LocalDateTime(date, time.withSecond(s)); }
    public LocalDateTime withNano(int n) { return new LocalDateTime(date, time.withNano(n)); }
    public LocalDateTime withDayOfMonth(int d) { return new LocalDateTime(date.withDayOfMonth(d), time); }
    public LocalDateTime withMonth(int m) { return new LocalDateTime(date.withMonth(m), time); }
    public LocalDateTime withYear(int y) { return new LocalDateTime(date.withYear(y), time); }
    public LocalDateTime truncatedTo(ChronoUnit u) { return new LocalDateTime(date, time.truncatedTo(u)); }
    public boolean isBefore(LocalDateTime o) { return compareTo(o) < 0; }
    public boolean isAfter(LocalDateTime o) { return compareTo(o) > 0; }
    public boolean isEqual(LocalDateTime o) { return compareTo(o) == 0; }
    public int compareTo(LocalDateTime o) { int c = date.compareTo(o.date); return c != 0 ? c : time.compareTo(o.time); }
    public long until(LocalDateTime end, TemporalUnit u) { return ((ChronoUnit) u).between(this, end); }
    public String format(DateTimeFormatter f) { return f.format(this); }
    public boolean equals(Object o) { return o instanceof LocalDateTime d && date.equals(d.date) && time.equals(d.time); }
    public int hashCode() { return date.hashCode() ^ time.hashCode(); }
    public String toString() { return date.toString() + 'T' + time.toString(); }
}
