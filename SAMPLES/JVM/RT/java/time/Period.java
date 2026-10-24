package java.time;
public final class Period implements java.io.Serializable {
    private Object writeReplace() { return new Ser(Ser.PERIOD_TYPE, this); }
    private void readObject(java.io.ObjectInputStream s) throws java.io.InvalidObjectException { throw new java.io.InvalidObjectException("Deserialization via serialization delegate"); }
    void writeExternal(java.io.DataOutput out) throws java.io.IOException { out.writeInt(years); out.writeInt(months); out.writeInt(days); }
    static Period readExternal(java.io.DataInput in) throws java.io.IOException { int years = in.readInt(); int months = in.readInt(); int days = in.readInt(); return Period.of(years, months, days); }
    private static final long serialVersionUID = -3587258372562876L;
    public static final Period ZERO = new Period(0, 0, 0);
    private final int years, months, days;
    private Period(int y, int m, int d) { years = y; months = m; days = d; }
    public static Period of(int y, int m, int d) { return new Period(y, m, d); }
    public static Period ofDays(int d) { return new Period(0, 0, d); }
    public static Period ofWeeks(int w) { return new Period(0, 0, w * 7); }
    public static Period ofMonths(int m) { return new Period(0, m, 0); }
    public static Period ofYears(int y) { return new Period(y, 0, 0); }
    public static Period between(LocalDate start, LocalDate end) {
        long totalMonths = (end.getYear() * 12L + end.getMonthValue() - 1) - (start.getYear() * 12L + start.getMonthValue() - 1);
        int days = end.getDayOfMonth() - start.getDayOfMonth();
        if (totalMonths > 0 && days < 0) {
            totalMonths--;
            LocalDate calcDate = start.plusMonths(totalMonths);
            days = (int) (end.toEpochDay() - calcDate.toEpochDay());
        } else if (totalMonths < 0 && days > 0) {
            totalMonths++;
            days -= end.lengthOfMonth();
        }
        return new Period((int) (totalMonths / 12), (int) (totalMonths % 12), days);
    }
    public int getYears() { return years; }
    public int getMonths() { return months; }
    public int getDays() { return days; }
    public long toTotalMonths() { return years * 12L + months; }
    public boolean isZero() { return years == 0 && months == 0 && days == 0; }
    public boolean isNegative() { return years < 0 || months < 0 || days < 0; }
    public Period plusDays(long d) { return new Period(years, months, (int) (days + d)); }
    public Period plusMonths(long m) { return new Period(years, (int) (months + m), days); }
    public Period plusYears(long y) { return new Period((int) (years + y), months, days); }
    public Period normalized() { long t = toTotalMonths(); return new Period((int) (t / 12), (int) (t % 12), days); }
    public boolean equals(Object o) { return o instanceof Period p && p.years == years && p.months == months && p.days == days; }
    public int hashCode() { return years + Integer.rotateLeft(months, 8) + Integer.rotateLeft(days, 16); }
    public String toString() {
        if (isZero()) return "P0D";
        StringBuilder buf = new StringBuilder();
        buf.append('P');
        if (years != 0) buf.append(years).append('Y');
        if (months != 0) buf.append(months).append('M');
        if (days != 0) buf.append(days).append('D');
        return buf.toString();
    }
}
