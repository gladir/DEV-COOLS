package java.time;
import java.time.temporal.*;
public final class Instant implements Temporal, Comparable<Instant>, java.io.Serializable {
    private Object writeReplace() { return new Ser(Ser.INSTANT_TYPE, this); }
    private void readObject(java.io.ObjectInputStream s) throws java.io.InvalidObjectException { throw new java.io.InvalidObjectException("Deserialization via serialization delegate"); }
    void writeExternal(java.io.DataOutput out) throws java.io.IOException { out.writeLong(seconds); out.writeInt(nanos); }
    static Instant readExternal(java.io.DataInput in) throws java.io.IOException { long seconds = in.readLong(); int nanos = in.readInt(); return Instant.ofEpochSecond(seconds, nanos); }
    private static final long serialVersionUID = -665713676816604388L;
    public static final Instant EPOCH = new Instant(0, 0);
    private final long seconds;
    private final int nanos;
    private Instant(long s, int n) { seconds = s; nanos = n; }
    public static Instant now() { long ms = System.currentTimeMillis(); return ofEpochMilli(ms); }
    public static Instant ofEpochSecond(long s) { return new Instant(s, 0); }
    public static Instant ofEpochSecond(long s, long adj) { return new Instant(s + Math.floorDiv(adj, 1000000000L), (int) Math.floorMod(adj, 1000000000L)); }
    public static Instant ofEpochMilli(long ms) { return new Instant(Math.floorDiv(ms, 1000L), (int) Math.floorMod(ms, 1000L) * 1000000); }
    public long getEpochSecond() { return seconds; }
    public int getNano() { return nanos; }
    public long toEpochMilli() { return seconds * 1000 + nanos / 1000000; }
    public Instant plus(Duration d) { return ofEpochSecond(seconds + d.getSeconds(), (long) nanos + d.getNano()); }
    public Instant minus(Duration d) { return ofEpochSecond(seconds - d.getSeconds(), (long) nanos - d.getNano()); }
    public Instant plusSeconds(long s) { return ofEpochSecond(seconds + s, nanos); }
    public Instant plusMillis(long ms) { return plus(Duration.ofMillis(ms)); }
    public Instant plusNanos(long n) { return plus(Duration.ofNanos(n)); }
    public Instant minusSeconds(long s) { return plusSeconds(-s); }
    public boolean isBefore(Instant o) { return compareTo(o) < 0; }
    public boolean isAfter(Instant o) { return compareTo(o) > 0; }
    public int compareTo(Instant o) { int c = Long.compare(seconds, o.seconds); return c != 0 ? c : nanos - o.nanos; }
    public boolean equals(Object o) { return o instanceof Instant i && i.seconds == seconds && i.nanos == nanos; }
    public int hashCode() { return ((int) (seconds ^ (seconds >>> 32))) + 51 * nanos; }
    public String toString() {
        LocalDateTime dt = LocalDateTime.ofEpochSecond(seconds, nanos);
        String s = dt.toString();
        if (dt.getSecond() == 0 && dt.getNano() == 0) s += ":00";
        return s + "Z";
    }
}
