package java.util;
public abstract class Calendar implements java.io.Serializable, Cloneable, Comparable<Calendar> {
    public static final int ERA = 0, YEAR = 1, MONTH = 2, WEEK_OF_YEAR = 3, WEEK_OF_MONTH = 4, DATE = 5, DAY_OF_MONTH = 5, DAY_OF_YEAR = 6, DAY_OF_WEEK = 7, DAY_OF_WEEK_IN_MONTH = 8, AM_PM = 9, HOUR = 10, HOUR_OF_DAY = 11, MINUTE = 12, SECOND = 13, MILLISECOND = 14;
    public static final int SUNDAY = 1, MONDAY = 2, TUESDAY = 3, WEDNESDAY = 4, THURSDAY = 5, FRIDAY = 6, SATURDAY = 7;
    public static final int JANUARY = 0, FEBRUARY = 1, MARCH = 2, APRIL = 3, MAY = 4, JUNE = 5, JULY = 6, AUGUST = 7, SEPTEMBER = 8, OCTOBER = 9, NOVEMBER = 10, DECEMBER = 11;
    public static final int AM = 0, PM = 1;
    protected long time;
    public static Calendar getInstance() { return new GregorianCalendar(); }
    public static Calendar getInstance(TimeZone z) { return new GregorianCalendar(); }
    public static Calendar getInstance(Locale l) { return new GregorianCalendar(); }
    public Date getTime() { return new Date(time); }
    public void setTime(Date d) { time = d.getTime(); }
    public long getTimeInMillis() { return time; }
    public void setTimeInMillis(long t) { time = t; }
    private java.time.LocalDateTime ldt() { return java.time.LocalDateTime.ofEpochSecond(Math.floorDiv(time, 1000L), (int) Math.floorMod(time, 1000L) * 1000000); }
    public int get(int f) {
        java.time.LocalDateTime t = ldt();
        switch (f) {
            case YEAR: return t.getYear(); case MONTH: return t.getMonthValue() - 1; case DAY_OF_MONTH: return t.getDayOfMonth(); case DAY_OF_YEAR: return t.getDayOfYear();
            case DAY_OF_WEEK: return t.getDayOfWeek().getValue() % 7 + 1; case HOUR_OF_DAY: return t.getHour(); case HOUR: return t.getHour() % 12; case AM_PM: return t.getHour() < 12 ? 0 : 1;
            case MINUTE: return t.getMinute(); case SECOND: return t.getSecond(); case MILLISECOND: return t.getNano() / 1000000;
            case WEEK_OF_YEAR: return (t.getDayOfYear() - 1) / 7 + 1;
        }
        throw new IllegalArgumentException();
    }
    public void set(int f, int v) {
        java.time.LocalDateTime t = ldt();
        switch (f) {
            case YEAR: t = t.withYear(v); break; case MONTH: t = t.withMonth(1).plusMonths(v); break; case DAY_OF_MONTH: t = t.withDayOfMonth(1).plusDays(v - 1); break;
            case HOUR_OF_DAY: t = t.withHour(0).plusHours(v); break; case MINUTE: t = t.withMinute(0).plusMinutes(v); break; case SECOND: t = t.withSecond(0).plusSeconds(v); break;
            case MILLISECOND: t = t.withNano(0).plusNanos(v * 1000000L); break;
            default: throw new IllegalArgumentException();
        }
        time = t.toEpochDay() * 86400000L + t.toLocalTime().toNanoOfDay() / 1000000L;
    }
    public void set(int y, int m, int d) { set(YEAR, y); set(MONTH, m); set(DAY_OF_MONTH, d); }
    public void set(int y, int m, int d, int h, int mi) { set(y, m, d); set(HOUR_OF_DAY, h); set(MINUTE, mi); }
    public void set(int y, int m, int d, int h, int mi, int s) { set(y, m, d, h, mi); set(SECOND, s); }
    public void add(int f, int amount) {
        java.time.LocalDateTime t = ldt();
        switch (f) {
            case YEAR: t = t.plusYears(amount); break; case MONTH: t = t.plusMonths(amount); break; case DAY_OF_MONTH: case DAY_OF_YEAR: t = t.plusDays(amount); break;
            case WEEK_OF_YEAR: t = t.plusWeeks(amount); break; case HOUR_OF_DAY: case HOUR: t = t.plusHours(amount); break; case MINUTE: t = t.plusMinutes(amount); break; case SECOND: t = t.plusSeconds(amount); break;
            case MILLISECOND: t = t.plusNanos(amount * 1000000L); break;
            default: throw new IllegalArgumentException();
        }
        time = t.toEpochDay() * 86400000L + t.toLocalTime().toNanoOfDay() / 1000000L;
    }
    public int getActualMaximum(int f) { if (f == DAY_OF_MONTH) return ldt().toLocalDate().lengthOfMonth(); if (f == DAY_OF_YEAR) return ldt().toLocalDate().lengthOfYear(); throw new IllegalArgumentException(); }
    public boolean before(Object o) { return o instanceof Calendar c && time < c.time; }
    public boolean after(Object o) { return o instanceof Calendar c && time > c.time; }
    public int compareTo(Calendar o) { return Long.compare(time, o.time); }
    public void clear() { time = 0; }
    public TimeZone getTimeZone() { return TimeZone.getDefault(); }
    public void setTimeZone(TimeZone z) { }
    public void setFirstDayOfWeek(int d) { }
}
