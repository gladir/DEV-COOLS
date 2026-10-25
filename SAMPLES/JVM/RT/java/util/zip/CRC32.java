package java.util.zip;
public class CRC32 implements Checksum {
    private int crc;
    public CRC32() { }
    public void update(int b) { crc = ZipSupport.crc32(crc, new byte[]{(byte) b}, 0, 1); }
    public void update(byte[] b, int off, int len) {
        if (b == null) throw new NullPointerException();
        if (off < 0 || len < 0 || off > b.length - len) throw new ArrayIndexOutOfBoundsException();
        crc = ZipSupport.crc32(crc, b, off, len);
    }
    public void update(byte[] b) { update(b, 0, b.length); }
    public void reset() { crc = 0; }
    public long getValue() { return (long) crc & 0xffffffffL; }
}
