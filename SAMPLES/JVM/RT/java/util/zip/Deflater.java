package java.util.zip;
public class Deflater {
    public static final int DEFLATED = 8, NO_COMPRESSION = 0, BEST_SPEED = 1, BEST_COMPRESSION = 9, DEFAULT_COMPRESSION = -1;
    public static final int FILTERED = 1, HUFFMAN_ONLY = 2, DEFAULT_STRATEGY = 0;
    public static final int NO_FLUSH = 0, SYNC_FLUSH = 2, FULL_FLUSH = 3;
    private int level;
    private final boolean nowrap;
    private byte[] in = new byte[0];
    private int inLen;
    private byte[] out;
    private int outPos;
    private boolean finish, finished;
    private long totalIn, totalOut;
    public Deflater(int level, boolean nowrap) { this.level = level; this.nowrap = nowrap; }
    public Deflater(int level) { this(level, false); }
    public Deflater() { this(DEFAULT_COMPRESSION, false); }
    public void setInput(byte[] b, int off, int len) {
        if (off < 0 || len < 0 || off > b.length - len) throw new ArrayIndexOutOfBoundsException();
        byte[] n = new byte[inLen + len];
        System.arraycopy(in, 0, n, 0, inLen);
        System.arraycopy(b, off, n, inLen, len);
        in = n; inLen = n.length;
    }
    public void setInput(byte[] b) { setInput(b, 0, b.length); }
    public void setDictionary(byte[] b) { }
    public void setStrategy(int strategy) { }
    public void setLevel(int level) { this.level = level; }
    public boolean needsInput() { return !finish; }
    public void finish() { finish = true; }
    public boolean finished() { return finished; }
    public int deflate(byte[] b, int off, int len) { return deflate(b, off, len, NO_FLUSH); }
    public int deflate(byte[] b) { return deflate(b, 0, b.length, NO_FLUSH); }
    public int deflate(byte[] b, int off, int len, int flush) {
        if (off < 0 || len < 0 || off > b.length - len) throw new ArrayIndexOutOfBoundsException();
        if (out == null) {
            if (!finish) return 0;
            int lv = level < 0 ? 6 : level;
            byte[] raw = ZipSupport.deflateRaw(in, 0, inLen, lv);
            if (nowrap) out = raw;
            else {
                out = new byte[raw.length + 6];
                out[0] = 0x78;
                out[1] = (byte) (lv == 0 || lv == 1 ? 0x01 : (lv >= 7 ? 0xDA : 0x9C));
                System.arraycopy(raw, 0, out, 2, raw.length);
                int ad = ZipSupport.adler32(1, in, 0, inLen);
                int q = raw.length + 2;
                out[q] = (byte) (ad >>> 24); out[q + 1] = (byte) (ad >>> 16); out[q + 2] = (byte) (ad >>> 8); out[q + 3] = (byte) ad;
            }
            totalIn = inLen;
        }
        int n = Math.min(len, out.length - outPos);
        System.arraycopy(out, outPos, b, off, n);
        outPos += n;
        totalOut += n;
        if (outPos >= out.length) finished = true;
        return n;
    }
    public int getAdler() { return ZipSupport.adler32(1, in, 0, inLen); }
    public int getTotalIn() { return (int) totalIn; }
    public int getTotalOut() { return (int) totalOut; }
    public long getBytesRead() { return totalIn; }
    public long getBytesWritten() { return totalOut; }
    public void reset() { in = new byte[0]; inLen = 0; out = null; outPos = 0; finish = false; finished = false; totalIn = totalOut = 0; }
    public void end() { }
}
