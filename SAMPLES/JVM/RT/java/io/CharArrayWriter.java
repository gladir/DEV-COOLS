package java.io;
public class CharArrayWriter extends Writer {
    protected char[] buf;
    protected int count;
    public CharArrayWriter() { this(32); }
    public CharArrayWriter(int initialSize) {
        if (initialSize < 0) throw new IllegalArgumentException("Negative initial size: " + initialSize);
        buf = new char[initialSize];
    }
    private void ensure(int n) { if (n > buf.length) buf = java.util.Arrays.copyOf(buf, Math.max(buf.length << 1, n)); }
    public void write(int c) { ensure(count + 1); buf[count++] = (char) c; }
    public void write(char[] c, int off, int len) { ensure(count + len); System.arraycopy(c, off, buf, count, len); count += len; }
    public void write(String str, int off, int len) { ensure(count + len); str.getChars(off, off + len, buf, count); count += len; }
    public void writeTo(Writer out) throws IOException { out.write(buf, 0, count); }
    public CharArrayWriter append(CharSequence csq) { String s = String.valueOf(csq); write(s, 0, s.length()); return this; }
    public CharArrayWriter append(char c) { write(c); return this; }
    public void reset() { count = 0; }
    public char[] toCharArray() { return java.util.Arrays.copyOf(buf, count); }
    public int size() { return count; }
    public String toString() { return new String(buf, 0, count); }
    public void flush() { }
    public void close() { }
}
