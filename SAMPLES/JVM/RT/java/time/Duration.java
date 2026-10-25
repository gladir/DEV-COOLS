package java.time;
import java.time.temporal.*;
public final class Duration implements Comparable<Duration>, java.io.Serializable {
    private Object writeReplace() { return new Ser(Ser.DURATION_TYPE, this); }
    private void readObject(java.io.ObjectInputStream s) throws java.io.InvalidObjectException { throw new java.io.InvalidObjectException("Deserialization via serialization delegate"); }
    void writeExternal(java.io.DataOutput out) throws java.io.IOException { out.writeLong(seconds); out.writeInt(nanos); }
    static Duration readExternal(java.io.DataInput in) throws java.io.IOException { long seconds = in.readLong(); int nanos = in.readInt(); return Duration.ofSeconds(seconds, nanos); }
    private static final long serialVersionUID = 3078945930695997490L;
    public static final Duration ZERO = new Duration(0, 0);
    private final long seconds;
    private final int nanos;
    private Duration(long s, int n) { seconds = s; nanos = n; }
    private static Duration create(long s, long n) {
        s = Math.addExact(s, Math.floorDiv(n, 1000000000L));
        int nn = (int) Math.floorMod(n, 1000000000L);
        if (s == 0 && nn == 0) return ZERO;
        return new Duration(s, nn);
    }
    public static Duration ofDays(long d) { return create(Math.multiplyExact(d, 86400L), 0); }
    public static Duration ofHours(long h) { return create(Math.multiplyExact(h, 3600L), 0); }
    public static Duration ofMinutes(long m) { return create(Math.multiplyExact(m, 60L), 0); }
    public static Duration ofSeconds(long s) { return create(s, 0); }
    public static Duration ofSeconds(long s, long adj) { return create(s, adj); }
    public static Duration ofMillis(long ms) { return create(Math.floorDiv(ms, 1000L), Math.floorMod(ms, 1000L) * 1000000L); }
    public static Duration ofNanos(long n) { return create(0, n); }
    public static Duration of(long amount, TemporalUnit unit) { return ofNanos(0).plus(amount, unit); }
    public static Duration between(Temporal a, Temporal b) {
        long n = ChronoUnit.NANOS.between(a, b);
        return ofNanos(n);
    }
    public long getSeconds() { return seconds; }
    public int getNano() { return nanos; }
    public boolean isZero() { return seconds == 0 && nanos == 0; }
    public boolean isNegative() { return seconds < 0; }
    public Duration plus(Duration d) { return create(Math.addExact(seconds, d.seconds), (long) nanos + d.nanos); }
    public Duration plus(long amount, TemporalUnit unit) { return create(seconds, nanos).plus(ofNanos(amount * ((ChronoUnit) unit).getDuration().toNanos())); }
    public Duration minus(Duration d) { return create(Math.subtractExact(seconds, d.seconds), (long) nanos - d.nanos); }
    public Duration plusDays(long d) { return plus(ofDays(d)); }
    public Duration plusHours(long h) { return plus(ofHours(h)); }
    public Duration plusMinutes(long m) { return plus(ofMinutes(m)); }
    public Duration plusSeconds(long s) { return plus(ofSeconds(s)); }
    public Duration plusMillis(long ms) { return plus(ofMillis(ms)); }
    public Duration plusNanos(long n) { return plus(ofNanos(n)); }
    public Duration minusMinutes(long m) { return minus(ofMinutes(m)); }
    public Duration minusSeconds(long s) { return minus(ofSeconds(s)); }
    public Duration multipliedBy(long k) { return ofNanos(0).plus(create(Math.multiplyExact(seconds, k), (long) nanos * k)); }
    public Duration dividedBy(long k) { return ofNanos(toNanos() / k); }
    public Duration negated() { return multipliedBy(-1); }
    public Duration abs() { return isNegative() ? negated() : this; }
    public long toDays() { return seconds / 86400; }
    public long toHours() { return seconds / 3600; }
    public long toMinutes() { return seconds / 60; }
    public long toSeconds() { return seconds; }
    public long toMillis() { return seconds * 1000 + nanos / 1000000; }
    public long toNanos() { return seconds * 1000000000L + nanos; }
    public long toDaysPart() { return seconds / 86400; }
    public int toHoursPart() { return (int) (toHours() % 24); }
    public int toMinutesPart() { return (int) (toMinutes() % 60); }
    public int toSecondsPart() { return (int) (seconds % 60); }
    public int toMillisPart() { return nanos / 1000000; }
    public int toNanosPart() { return nanos; }
    public int compareTo(Duration o) { int c = Long.compare(seconds, o.seconds); return c != 0 ? c : nanos - o.nanos; }
    public boolean equals(Object o) { return o instanceof Duration d && d.seconds == seconds && d.nanos == nanos; }
    public int hashCode() { return ((int) (seconds ^ (seconds >>> 32))) + (51 * nanos); }
    public String toString() {
        if (this == ZERO || (seconds == 0 && nanos == 0)) return "PT0S";
        long effectiveTotalSecs = seconds;
        if (seconds < 0 && nanos > 0) effectiveTotalSecs++;
        long hours = effectiveTotalSecs / 3600;
        int minutes = (int) ((effectiveTotalSecs % 3600) / 60);
        int secs = (int) (effectiveTotalSecs % 60);
        StringBuilder buf = new StringBuilder(24);
        buf.append("PT");
        if (hours != 0) buf.append(hours).append('H');
        if (minutes != 0) buf.append(minutes).append('M');
        if (secs == 0 && nanos == 0 && buf.length() > 2) return buf.toString();
        if (seconds < 0 && nanos > 0) { if (secs == 0) buf.append("-0"); else buf.append(secs); } else buf.append(secs);
        if (nanos > 0) {
            int pos = buf.length();
            if (seconds < 0) buf.append(2 * 1000000000L - nanos); else buf.append(nanos + 1000000000L);
            while (buf.charAt(buf.length() - 1) == '0') buf.setLength(buf.length() - 1);
            buf.setCharAt(pos, '.');
        }
        buf.append('S');
        return buf.toString();
    }
}
