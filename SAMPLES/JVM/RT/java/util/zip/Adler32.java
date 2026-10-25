package java.util.zip;
public class Adler32 implements Checksum {
    private int adler = 1;
    public Adler32() { }
    public void update(int b) { adler = ZipSupport.adler32(adler, new byte[]{(byte) b}, 0, 1); }
    public void update(byte[] b, int off, int len) { adler = ZipSupport.adler32(adler, b, off, len); }
    public void update(byte[] b) { update(b, 0, b.length); }
    public void reset() { adler = 1; }
    public long getValue() { return (long) adler & 0xffffffffL; }
}
