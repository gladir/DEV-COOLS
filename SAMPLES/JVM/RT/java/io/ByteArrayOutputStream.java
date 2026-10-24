package java.io;
public class ByteArrayOutputStream extends OutputStream {
    protected byte[] buf = new byte[32];
    protected int count;
    public ByteArrayOutputStream() {}
    public ByteArrayOutputStream(int size) { buf = new byte[Math.max(size, 1)]; }
    public void write(int b) {
        if (count == buf.length) buf = java.util.Arrays.copyOf(buf, count * 2);
        buf[count++] = (byte) b;
    }
    public void write(byte[] b, int off, int len) { for (int i = 0; i < len; i++) write(b[off + i]); }
    public byte[] toByteArray() { return java.util.Arrays.copyOf(buf, count); }
    public int size() { return count; }
    public void reset() { count = 0; }
    public String toString() { return new String(buf, 0, count); }
    public String toString(String cs) { return new String(buf, 0, count); }
    public String toString(java.nio.charset.Charset cs) { return new String(buf, 0, count, cs); }
}
