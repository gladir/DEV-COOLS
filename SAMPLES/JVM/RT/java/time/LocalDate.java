package java.time;
import java.time.temporal.*;
import java.time.format.*;
public final class LocalDate implements Temporal, Comparable<LocalDate> {
    public static final LocalDate MIN = new LocalDate(-999999999, 1, 1), MAX = new LocalDate(999999999, 12, 31), EPOCH = new LocalDate(1970, 1, 1);
    private final int year, month, day;
    private LocalDate(int y, int m, int d) { year = y; month = m; day = d; }
    public static LocalDate of(int y, int m, int d) {
        if (m < 1 || m > 12) throw new DateTimeException("Invalid value for MonthOfYear (valid values 1 - 12): " + m);
        if (d < 1 || d > 31) throw new DateTimeException("Invalid value for DayOfMonth (valid values 1 - 28/31): " + d);
        if (d > 28 && d > Month.of(m).length(Year.isLeap(y))) {
            if (d == 29) throw new DateTimeException("Invalid date 'February 29' as '" + y + "' is not a leap year");
            throw new DateTimeException("Invalid date '" + Month.of(m).name() + " " + d + "'");
        }
        return new LocalDate(y, m, d);
    }
    public static LocalDate of(int y, Month m, int d) { return of(y, m.getValue(), d); }
    public static LocalDate ofYearDay(int y, int doy) { return of(y, 1, 1).plusDays(doy - 1); }
    public static LocalDate now() { return ofEpochDay(Math.floorDiv(System.currentTimeMillis(), 86400000L)); }
    public static LocalDate ofEpochDay(long epochDay) {
        long zeroDay = epochDay + 719528;
        zeroDay -= 60;
        long adjust = 0;
        if (zeroDay < 0) { long adjustCycles = (zeroDay + 1) / 146097 - 1; adjust = adjustCycles * 400; zeroDay += -adjustCycles * 146097; }
        long yearEst = (400 * zeroDay + 591) / 146097;
        long doyEst = zeroDay - (365 * yearEst + yearEst / 4 - yearEst / 100 + yearEst / 400);
        if (doyEst < 0) { yearEst--; doyEst = zeroDay - (365 * yearEst + yearEst / 4 - yearEst / 100 + yearEst / 400); }
        yearEst += adjust;
        int marchDoy0 = (int) doyEst;
        int marchMonth0 = (marchDoy0 * 5 + 2) / 153;
        int month = (marchMonth0 + 2) % 12 + 1;
        int dom = marchDoy0 - (marchMonth0 * 306 + 5) / 10 + 1;
        yearEst += marchMonth0 / 10;
        return new LocalDate((int) yearEst, month, dom);
    }
    public long toEpochDay() {
        long y = year, m = month, total = 0;
        total += 365 * y;
        if (y >= 0) total += (y + 3) / 4 - (y + 99) / 100 + (y + 399) / 400; else total -= y / -4 - y / -100 + y / -400;
        total += ((367 * m - 362) / 12);
        total += day - 1;
        if (m > 2) { total--; if (!isLeapYear()) total--; }
        return total - 719528;
    }
    public static LocalDate parse(CharSequence text) {
        String s = text.toString();
        try {
            if (s.length() < 10 || s.charAt(s.length() - 6) != '-' && s.charAt(4) != '-') throw new RuntimeException();
            int y = Integer.parseInt(s.substring(0, 4)), m = Integer.parseInt(s.substring(5, 7)), d = Integer.parseInt(s.substring(8, 10));
            if (s.length() != 10) throw new RuntimeException();
            return of(y, m, d);
        } catch (DateTimeException e) { throw new DateTimeParseException("Text '" + s + "' could not be parsed: " + e.getMessage(), s, 0); }
        catch (RuntimeException e) { throw new DateTimeParseException("Text '" + s + "' could not be parsed at index 0", s, 0); }
    }
    public static LocalDate parse(CharSequence text, DateTimeFormatter f) { return f.parseDate(text.toString()); }
    public int getYear() { return year; }
    public int getMonthValue() { return month; }
    public Month getMonth() { return Month.of(month); }
    public int getDayOfMonth() { return day; }
    public int getDayOfYear() { return (int) (toEpochDay() - of(year, 1, 1).toEpochDay()) + 1; }
    public DayOfWeek getDayOfWeek() { return DayOfWeek.of((int) Math.floorMod(toEpochDay() + 3, 7L) + 1); }
    public boolean isLeapYear() { return Year.isLeap(year); }
    public int lengthOfMonth() { return Month.of(month).length(isLeapYear()); }
    public int lengthOfYear() { return isLeapYear() ? 366 : 365; }
    public LocalDate plusDays(long d) { return d == 0 ? this : ofEpochDay(toEpochDay() + d); }
    public LocalDate plusWeeks(long w) { return plusDays(w * 7); }
    public LocalDate plusMonths(long m) {
        if (m == 0) return this;
        long calc = year * 12L + (month - 1) + m;
        int ny = (int) Math.floorDiv(calc, 12L);
        int nm = (int) Math.floorMod(calc, 12L) + 1;
        return new LocalDate(ny, nm, Math.min(day, Month.of(nm).length(Year.isLeap(ny))));
    }
    public LocalDate plusYears(long y) { return y == 0 ? this : plusMonths(y * 12); }
    public LocalDate minusDays(long d) { return plusDays(-d); }
    public LocalDate minusWeeks(long w) { return plusWeeks(-w); }
    public LocalDate minusMonths(long m) { return plusMonths(-m); }
    public LocalDate minusYears(long y) { return plusYears(-y); }
    public LocalDate plus(long amount, TemporalUnit u) {
        switch ((ChronoUnit) u) {
            case DAYS: return plusDays(amount); case WEEKS: return plusWeeks(amount); case MONTHS: return plusMonths(amount); case YEARS: return plusYears(amount);
            case DECADES: return plusYears(amount * 10); case CENTURIES: return plusYears(amount * 100);
            default: throw new UnsupportedTemporalTypeException("Unsupported unit: " + u);
        }
    }
    public LocalDate minus(long amount, TemporalUnit u) { return plus(-amount, u); }
    public LocalDate plus(Period p) { return plusMonths(p.toTotalMonths()).plusDays(p.getDays()); }
    public LocalDate minus(Period p) { return plusMonths(-p.toTotalMonths()).plusDays(-p.getDays()); }
    public LocalDate withDayOfMonth(int d) { return of(year, month, d); }
    public LocalDate withMonth(int m) { return new LocalDate(year, m, Math.min(day, Month.of(m).length(isLeapYear()))); }
    public LocalDate withYear(int y) { return new LocalDate(y, month, Math.min(day, Month.of(month).length(Year.isLeap(y)))); }
    public LocalDate withDayOfYear(int d) { return ofYearDay(year, d); }
    public long until(LocalDate end, TemporalUnit u) { return ((ChronoUnit) u).between(this, end); }
    public Period until(LocalDate end) { return Period.between(this, end); }
    public LocalDateTime atStartOfDay() { return LocalDateTime.of(this, LocalTime.MIDNIGHT); }
    public LocalDateTime atTime(int h, int m) { return LocalDateTime.of(this, LocalTime.of(h, m)); }
    public LocalDateTime atTime(int h, int m, int s) { return LocalDateTime.of(this, LocalTime.of(h, m, s)); }
    public LocalDateTime atTime(LocalTime t) { return LocalDateTime.of(this, t); }
    public java.util.stream.Stream<LocalDate> datesUntil(LocalDate end) {
        java.util.ArrayList<LocalDate> l = new java.util.ArrayList<>();
        for (LocalDate d = this; d.isBefore(end); d = d.plusDays(1)) l.add(d);
        return l.stream();
    }
    public boolean isBefore(LocalDate o) { return compareTo(o) < 0; }
    public boolean isAfter(LocalDate o) { return compareTo(o) > 0; }
    public boolean isEqual(LocalDate o) { return compareTo(o) == 0; }
    public int compareTo(LocalDate o) { int c = year - o.year; if (c == 0) { c = month - o.month; if (c == 0) c = day - o.day; } return c; }
    public String format(DateTimeFormatter f) { return f.format(this); }
    public boolean equals(Object o) { return o instanceof LocalDate d && compareTo(d) == 0; }
    public int hashCode() { return (year & 0xFFFFF800) ^ ((year << 11) + (month << 6) + day); }
    public String toString() {
        int absYear = Math.abs(year);
        StringBuilder buf = new StringBuilder(10);
        if (absYear < 1000) { if (year < 0) buf.append(year - 10000).deleteCharAt(1); else buf.append(year + 10000).deleteCharAt(0); }
        else { if (year > 9999) buf.append('+'); buf.append(year); }
        return buf.append(month < 10 ? "-0" : "-").append(month).append(day < 10 ? "-0" : "-").append(day).toString();
    }
}
