package java.io;
public class ByteArrayOutputStream extends OutputStream {
    protected byte[] buf;
    protected int count;
    public ByteArrayOutputStream() { this(32); }
    public ByteArrayOutputStream(int size) {
        if (size < 0) throw new IllegalArgumentException("Negative initial size: " + size);
        buf = new byte[size];
    }
    private void ensure(int min) {
        if (min > buf.length) buf = java.util.Arrays.copyOf(buf, Math.max(Math.max(buf.length * 2, min), 8));
    }
    public synchronized void write(int b) { ensure(count + 1); buf[count++] = (byte) b; }
    public synchronized void write(byte[] b, int off, int len) {
        if (off < 0 || len < 0 || off + len > b.length) throw new IndexOutOfBoundsException("Range [" + off + ", " + off + " + " + len + ") out of bounds for length " + b.length);
        ensure(count + len);
        System.arraycopy(b, off, buf, count, len);
        count += len;
    }
    public void writeBytes(byte[] b) { write(b, 0, b.length); }
    public synchronized void writeTo(OutputStream out) throws IOException { out.write(buf, 0, count); }
    public synchronized void reset() { count = 0; }
    public synchronized byte[] toByteArray() { return java.util.Arrays.copyOf(buf, count); }
    public synchronized int size() { return count; }
    public synchronized String toString() { return new String(buf, 0, count); }
    public synchronized String toString(String cs) throws UnsupportedEncodingException { return new String(buf, 0, count, java.nio.charset.Charset.forName(cs)); }
    public synchronized String toString(java.nio.charset.Charset cs) { return new String(buf, 0, count, cs); }
    public void close() throws IOException { }
}
