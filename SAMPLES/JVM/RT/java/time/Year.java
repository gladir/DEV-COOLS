package java.time;
public final class Year implements java.io.Serializable {
    private Object writeReplace() { return new Ser(Ser.YEAR_TYPE, this); }
    private void readObject(java.io.ObjectInputStream s) throws java.io.InvalidObjectException { throw new java.io.InvalidObjectException("Deserialization via serialization delegate"); }
    void writeExternal(java.io.DataOutput out) throws java.io.IOException { out.writeInt(year); }
    static Year readExternal(java.io.DataInput in) throws java.io.IOException { return Year.of(in.readInt()); }
    private static final long serialVersionUID = -23038383694477807L;
    private final int year;
    private Year(int y) { year = y; }
    public static Year of(int y) { return new Year(y); }
    public static Year now() { return new Year(LocalDate.now().getYear()); }
    public static boolean isLeap(long y) { return ((y & 3) == 0) && ((y % 100) != 0 || (y % 400) == 0); }
    public boolean isLeap() { return isLeap(year); }
    public int getValue() { return year; }
    public int length() { return isLeap() ? 366 : 365; }
    public String toString() { return Integer.toString(year); }
}
