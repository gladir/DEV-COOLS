package java.util;
public final class UUID implements java.io.Serializable, Comparable<UUID> {
    private final long msb, lsb;
    public UUID(long msb, long lsb) { this.msb = msb; this.lsb = lsb; }
    private static Random rnd;
    public static UUID randomUUID() {
        if (rnd == null) rnd = new Random();
        long m = rnd.nextLong(), l = rnd.nextLong();
        m &= ~0xF000L; m |= 0x4000L;
        l &= 0x3FFFFFFFFFFFFFFFL; l |= 0x8000000000000000L;
        return new UUID(m, l);
    }
    public static UUID fromString(String s) {
        String[] p = s.split("-");
        if (p.length != 5) throw new IllegalArgumentException("Invalid UUID string: " + s);
        long m = Long.parseLong(p[0], 16) << 32 | Long.parseLong(p[1], 16) << 16 | Long.parseLong(p[2], 16);
        long l = Long.parseLong(p[3], 16) << 48 | Long.parseLong(p[4], 16);
        return new UUID(m, l);
    }
    public long getMostSignificantBits() { return msb; }
    public long getLeastSignificantBits() { return lsb; }
    private static String digits(long val, int digits) { long hi = 1L << (digits * 4); return Long.toHexString(hi | (val & (hi - 1))).substring(1); }
    public String toString() { return digits(msb >> 32, 8) + "-" + digits(msb >> 16, 4) + "-" + digits(msb, 4) + "-" + digits(lsb >> 48, 4) + "-" + digits(lsb, 12); }
    public int hashCode() { long h = msb ^ lsb; return ((int) (h >> 32)) ^ (int) h; }
    public boolean equals(Object o) { return o instanceof UUID u && u.msb == msb && u.lsb == lsb; }
    public int compareTo(UUID o) { return msb < o.msb ? -1 : (msb > o.msb ? 1 : (lsb < o.lsb ? -1 : (lsb > o.lsb ? 1 : 0))); }
}
