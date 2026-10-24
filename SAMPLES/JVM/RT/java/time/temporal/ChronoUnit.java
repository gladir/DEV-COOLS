package java.time.temporal;
import java.time.*;
public enum ChronoUnit implements TemporalUnit {
    NANOS("Nanos", 1L), MICROS("Micros", 1000L), MILLIS("Millis", 1000000L), SECONDS("Seconds", 1000000000L), MINUTES("Minutes", 60000000000L), HOURS("Hours", 3600000000000L),
    HALF_DAYS("HalfDays", 43200000000000L), DAYS("Days", 86400000000000L), WEEKS("Weeks", 7 * 86400000000000L), MONTHS("Months", 0), YEARS("Years", 0), DECADES("Decades", 0), CENTURIES("Centuries", 0);
    private final String name;
    final long nanos;
    ChronoUnit(String n, long nanos) { name = n; this.nanos = nanos; }
    public Duration getDuration() { return Duration.ofNanos(nanos); }
    public String toString() { return name; }
    public long between(Temporal a, Temporal b) {
        if (a instanceof LocalDate x && b instanceof LocalDate y) {
            switch (this) {
                case DAYS: return y.toEpochDay() - x.toEpochDay();
                case WEEKS: return (y.toEpochDay() - x.toEpochDay()) / 7;
                case MONTHS: return monthsBetween(x, y);
                case YEARS: return monthsBetween(x, y) / 12;
                case DECADES: return monthsBetween(x, y) / 120;
                case CENTURIES: return monthsBetween(x, y) / 1200;
                default: throw new UnsupportedTemporalTypeException("Unsupported unit: " + this);
            }
        }
        if (a instanceof LocalDateTime x && b instanceof LocalDateTime y) {
            if (ordinal() >= DAYS.ordinal()) {
                LocalDate ed = y.toLocalDate();
                if (ed.isAfter(x.toLocalDate()) && y.toLocalTime().isBefore(x.toLocalTime())) ed = ed.minusDays(1);
                else if (ed.isBefore(x.toLocalDate()) && y.toLocalTime().isAfter(x.toLocalTime())) ed = ed.plusDays(1);
                return between(x.toLocalDate(), ed);
            }
            long n = (y.toEpochDay() - x.toEpochDay()) * 86400000000000L + (y.toLocalTime().toNanoOfDay() - x.toLocalTime().toNanoOfDay());
            return n / nanos;
        }
        if (a instanceof LocalTime x && b instanceof LocalTime y) return (y.toNanoOfDay() - x.toNanoOfDay()) / nanos;
        if (a instanceof Instant x && b instanceof Instant y) return ((y.getEpochSecond() - x.getEpochSecond()) * 1000000000L + (y.getNano() - x.getNano())) / nanos;
        throw new DateTimeException("Unsupported temporal types");
    }
    private static long monthsBetween(LocalDate x, LocalDate y) {
        long packed1 = x.getYear() * 12L + x.getMonthValue() - 1, packed2 = y.getYear() * 12L + y.getMonthValue() - 1;
        long total = packed2 - packed1;
        if (total > 0 && y.getDayOfMonth() < x.getDayOfMonth()) total--;
        else if (total < 0 && y.getDayOfMonth() > x.getDayOfMonth()) total++;
        return total;
    }
}
