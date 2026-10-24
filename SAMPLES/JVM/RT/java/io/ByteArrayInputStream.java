package java.io;
public class ByteArrayInputStream extends InputStream {
    protected byte[] buf;
    protected int pos, count;
    public ByteArrayInputStream(byte[] buf) { this.buf = buf; this.count = buf.length; }
    public int read() { return pos < count ? (buf[pos++] & 0xff) : -1; }
    public int available() { return count - pos; }
}
