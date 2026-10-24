package java.util.zip;
public class Inflater {
    private final boolean nowrap;
    private byte[] in = new byte[0];
    private int inLen;
    private byte[] out;
    private int outPos;
    private boolean decoded, finished, needDict;
    private int remaining;
    private long totalIn, totalOut;
    private int adler = 1;
    public Inflater(boolean nowrap) { this.nowrap = nowrap; }
    public Inflater() { this(false); }
    public void setInput(byte[] b, int off, int len) {
        if (off < 0 || len < 0 || off > b.length - len) throw new ArrayIndexOutOfBoundsException();
        if (decoded && outPos >= out.length) { in = new byte[0]; inLen = 0; }
        byte[] n = new byte[inLen + len];
        System.arraycopy(in, 0, n, 0, inLen);
        System.arraycopy(b, off, n, inLen, len);
        in = n; inLen = n.length;
    }
    public void setInput(byte[] b) { setInput(b, 0, b.length); }
    public void setDictionary(byte[] b) { }
    public int getRemaining() { return decoded ? remaining : inLen; }
    public boolean needsInput() { return !decoded && !finished; }
    public boolean needsDictionary() { return false; }
    public boolean finished() { return finished; }
    public int inflate(byte[] b, int off, int len) throws DataFormatException {
        if (off < 0 || len < 0 || off > b.length - len) throw new ArrayIndexOutOfBoundsException();
        if (!decoded) {
            int hdr = 0;
            if (!nowrap) {
                if (inLen < 2) return 0;
                int cmf = in[0] & 255, flg = in[1] & 255;
                if ((cmf & 15) != 8 || ((cmf << 8) | flg) % 31 != 0) throw new DataFormatException("incorrect header check");
                hdr = 2;
                if ((flg & 32) != 0) throw new DataFormatException("need dictionary");
            }
            int[] consumed = new int[1];
            byte[] res = ZipSupport.inflate0(in, hdr, inLen - hdr, consumed);
            if (consumed[0] < 0) throw new DataFormatException("invalid stored block lengths");
            if (res == null) return 0;
            int used = hdr + consumed[0];
            if (!nowrap) {
                if (inLen - used < 4) return 0;
                int expect = ((in[used] & 255) << 24) | ((in[used + 1] & 255) << 16) | ((in[used + 2] & 255) << 8) | (in[used + 3] & 255);
                int got = ZipSupport.adler32(1, res, 0, res.length);
                if (expect != got) throw new DataFormatException("incorrect data check");
                used += 4;
                adler = got;
            }
            out = res; outPos = 0; decoded = true;
            remaining = inLen - used;
            totalIn += used;
        }
        int n = Math.min(len, out.length - outPos);
        System.arraycopy(out, outPos, b, off, n);
        outPos += n;
        totalOut += n;
        if (outPos >= out.length) finished = true;
        return n;
    }
    public int inflate(byte[] b) throws DataFormatException { return inflate(b, 0, b.length); }
    public int getAdler() { return adler; }
    public int getTotalIn() { return (int) totalIn; }
    public int getTotalOut() { return (int) totalOut; }
    public long getBytesRead() { return totalIn; }
    public long getBytesWritten() { return totalOut; }
    public void reset() { in = new byte[0]; inLen = 0; out = null; outPos = 0; decoded = false; finished = false; remaining = 0; totalIn = totalOut = 0; adler = 1; }
    public void end() { }
}
