package java.util.zip;
public class ZipEntry implements Cloneable {
    String name;
    long xdostime = -1;
    long crc = -1;
    long size = -1;
    long csize = -1;
    int method = -1;
    int flag = 0;
    byte[] extra;
    String comment;
    long headerOff;
    public static final int STORED = 0;
    public static final int DEFLATED = 8;
    public ZipEntry(String name) {
        java.util.Objects.requireNonNull(name, "name");
        if (name.length() > 0xFFFF) throw new IllegalArgumentException("entry name too long");
        this.name = name;
    }
    public ZipEntry(ZipEntry e) {
        java.util.Objects.requireNonNull(e, "entry");
        name = e.name; xdostime = e.xdostime; crc = e.crc; size = e.size; csize = e.csize; method = e.method; flag = e.flag; extra = e.extra; comment = e.comment;
    }
    public String getName() { return name; }
    private static long toDos(long millis) {
        java.time.LocalDateTime t = java.time.LocalDateTime.ofEpochSecond(Math.floorDiv(millis, 1000L), 0);
        int year = t.getYear();
        if (year < 1980) return (1 << 21) | (1 << 16);
        return ((long) (year - 1980) << 25) | ((long) t.getMonthValue() << 21) | ((long) t.getDayOfMonth() << 16) | ((long) t.getHour() << 11) | ((long) t.getMinute() << 5) | ((long) t.getSecond() >> 1);
    }
    public void setTime(long time) { xdostime = toDos(time); }
    public long getTime() {
        if (xdostime == -1) return -1;
        int dt = (int) xdostime;
        int year = ((dt >> 25) & 0x7f) + 1980, mon = (dt >> 21) & 0x0f, day = (dt >> 16) & 0x1f, hour = (dt >> 11) & 0x1f, min = (dt >> 5) & 0x3f, sec = (dt << 1) & 0x3e;
        java.time.LocalDateTime t = java.time.LocalDateTime.of(year, Math.max(1, mon), Math.max(1, day), hour, min, sec);
        return (t.toEpochDay() * 86400L + t.toLocalTime().toSecondOfDay()) * 1000L;
    }
    public void setSize(long size) { if (size < 0) throw new IllegalArgumentException("invalid entry size"); this.size = size; }
    public long getSize() { return size; }
    public long getCompressedSize() { return csize; }
    public void setCompressedSize(long csize) { this.csize = csize; }
    public void setCrc(long crc) { if (crc < 0 || crc > 0xFFFFFFFFL) throw new IllegalArgumentException("invalid entry crc-32"); this.crc = crc; }
    public long getCrc() { return crc; }
    public void setMethod(int method) { if (method != STORED && method != DEFLATED) throw new IllegalArgumentException("invalid compression method"); this.method = method; }
    public int getMethod() { return method; }
    public void setExtra(byte[] extra) { this.extra = extra; }
    public byte[] getExtra() { return extra; }
    public void setComment(String comment) { this.comment = comment; }
    public String getComment() { return comment; }
    public boolean isDirectory() { return name.endsWith("/"); }
    public String toString() { return getName(); }
    public int hashCode() { return name.hashCode(); }
    public Object clone() { return new ZipEntry(this); }
}
