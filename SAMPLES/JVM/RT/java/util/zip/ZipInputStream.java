package java.util.zip;
import java.io.*;
public class ZipInputStream extends InflaterInputStream {
    private byte[] data;
    private int pos;
    private ZipEntry entry;
    private byte[] cur;
    private int curPos;
    private boolean closed;
    private boolean eos;
    public ZipInputStream(InputStream in) { super(new PushbackInputStream(in, 512), new Inflater(true), 512); usesDefaultInflater = true; }
    public ZipInputStream(InputStream in, java.nio.charset.Charset charset) { this(in); }
    private void ensureOpen() throws IOException { if (closed) throw new IOException("Stream closed"); }
    private void load() throws IOException {
        if (data == null) { data = in.readAllBytes(); pos = 0; }
    }
    private static int u2(byte[] b, int p) { return (b[p] & 255) | ((b[p + 1] & 255) << 8); }
    private static long u4(byte[] b, int p) { return ((long) (b[p] & 255)) | ((long) (b[p + 1] & 255) << 8) | ((long) (b[p + 2] & 255) << 16) | ((long) (b[p + 3] & 255) << 24); }
    public ZipEntry getNextEntry() throws IOException {
        ensureOpen();
        load();
        if (entry != null) closeEntry();
        if (pos + 30 > data.length || u4(data, pos) != ZipConstants.LOCSIG) { eos = true; return null; }
        int flag = u2(data, pos + 6), method = u2(data, pos + 8);
        ZipEntry e = createZipEntry(new String(data, pos + 30, u2(data, pos + 26), java.nio.charset.StandardCharsets.UTF_8));
        e.flag = flag;
        e.method = method;
        e.xdostime = u4(data, pos + 10);
        int nl = u2(data, pos + 26), el = u2(data, pos + 28);
        if ((flag & 8) == 0) { e.crc = u4(data, pos + 14); e.csize = u4(data, pos + 18); e.size = u4(data, pos + 22); }
        int start = pos + 30 + nl + el;
        if (el > 0) e.extra = java.util.Arrays.copyOfRange(data, pos + 30 + nl, start);
        if (method == ZipEntry.STORED) {
            if ((flag & 8) != 0) throw new ZipException("only DEFLATED entries can have EXT descriptor");
            cur = java.util.Arrays.copyOfRange(data, start, start + (int) e.csize);
            pos = start + (int) e.csize;
        } else if (method == ZipEntry.DEFLATED) {
            int[] consumed = new int[1];
            byte[] res = ZipSupport.inflate0(data, start, data.length - start, consumed);
            if (res == null || consumed[0] < 0) throw new ZipException("invalid block type");
            cur = res;
            pos = start + consumed[0];
            if ((flag & 8) != 0) {
                if (pos + 4 <= data.length && u4(data, pos) == ZipConstants.EXTSIG) pos += 4;
                e.crc = u4(data, pos); e.csize = u4(data, pos + 4); e.size = u4(data, pos + 8);
                pos += 12;
            }
        } else throw new ZipException("invalid compression method");
        curPos = 0;
        entry = e;
        return e;
    }
    protected ZipEntry createZipEntry(String name) { return new ZipEntry(name); }
    public void closeEntry() throws IOException { ensureOpen(); entry = null; cur = null; }
    public int available() throws IOException { ensureOpen(); return eos ? 0 : 1; }
    public int read(byte[] b, int off, int len) throws IOException {
        ensureOpen();
        if (off < 0 || len < 0 || off > b.length - len) throw new IndexOutOfBoundsException();
        else if (len == 0) return 0;
        if (entry == null || cur == null) return -1;
        if (curPos >= cur.length) return -1;
        int n = Math.min(len, cur.length - curPos);
        System.arraycopy(cur, curPos, b, off, n);
        curPos += n;
        return n;
    }
    public int read() throws IOException { byte[] one = new byte[1]; return read(one, 0, 1) == -1 ? -1 : one[0] & 255; }
    public long skip(long n) throws IOException {
        if (n < 0) throw new IllegalArgumentException("negative skip length");
        ensureOpen();
        if (cur == null) return 0;
        int k = (int) Math.min(n, cur.length - curPos);
        curPos += k;
        return k;
    }
    public void close() throws IOException { if (!closed) { super.close(); closed = true; } }
}
