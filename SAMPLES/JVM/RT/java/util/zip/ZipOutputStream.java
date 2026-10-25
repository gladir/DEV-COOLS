package java.util.zip;
import java.io.*;
import java.util.*;
public class ZipOutputStream extends DeflaterOutputStream {
    public static final int STORED = ZipEntry.STORED;
    public static final int DEFLATED = ZipEntry.DEFLATED;
    private ZipEntry current;
    private ByteArrayOutputStream cur;
    private final List<ZipEntry> written = new ArrayList<>();
    private final Set<String> names = new HashSet<>();
    private final OutputStream raw;
    private long pos;
    private String comment;
    private int method = DEFLATED;
    private int level = -1;
    private boolean finished, closed;
    public ZipOutputStream(OutputStream out) { super(out, new Deflater(Deflater.DEFAULT_COMPRESSION, true)); raw = out; usesDefaultDeflater = true; }
    public ZipOutputStream(OutputStream out, java.nio.charset.Charset charset) { this(out); }
    public void setComment(String comment) { this.comment = comment; }
    public void setMethod(int method) { if (method != DEFLATED && method != STORED) throw new IllegalArgumentException("invalid compression method"); this.method = method; }
    public void setLevel(int level) { this.level = level; }
    private void ensureOpen() throws IOException { if (closed) throw new IOException("Stream closed"); }
    private void w2(int v) throws IOException { raw.write(v & 255); raw.write((v >> 8) & 255); pos += 2; }
    private void w4(long v) throws IOException { w2((int) (v & 0xffff)); w2((int) ((v >> 16) & 0xffff)); }
    public void putNextEntry(ZipEntry e) throws IOException {
        ensureOpen();
        if (current != null) closeEntry();
        if (e.xdostime == -1) e.setTime(System.currentTimeMillis());
        if (e.method == -1) e.method = method;
        if (!names.add(e.name)) throw new ZipException("duplicate entry: " + e.name);
        if (e.method == STORED) {
            if (e.size == -1) e.size = e.csize;
            else if (e.csize == -1) e.csize = e.size;
            if (e.size == -1 || e.crc == -1) throw new ZipException("STORED entry missing size, compressed size, or crc-32");
        }
        current = e;
        cur = new ByteArrayOutputStream();
    }
    public void closeEntry() throws IOException {
        ensureOpen();
        if (current == null) return;
        ZipEntry e = current;
        byte[] data = cur.toByteArray();
        CRC32 c = new CRC32();
        c.update(data, 0, data.length);
        byte[] body;
        if (e.method == STORED) {
            if (e.size != data.length) throw new ZipException("invalid entry size (expected " + e.size + " but got " + data.length + " bytes)");
            if (e.crc != c.getValue()) throw new ZipException("invalid entry crc-32 (expected 0x" + Long.toHexString(e.crc) + " but got 0x" + Long.toHexString(c.getValue()) + ")");
            body = data;
        } else {
            body = ZipSupport.deflateRaw(data, 0, data.length, level < 0 ? 6 : level);
            e.size = data.length; e.csize = body.length; e.crc = c.getValue();
        }
        e.headerOff = pos;
        byte[] nm = e.name.getBytes(java.nio.charset.StandardCharsets.UTF_8);
        boolean utf8 = nm.length != e.name.length();
        e.flag = utf8 ? 0x800 : 0;
        w4(ZipConstants.LOCSIG);
        w2(e.method == STORED ? 10 : 20);
        w2(e.flag);
        w2(e.method);
        w4(e.xdostime);
        w4(e.crc);
        w4(e.csize);
        w4(e.size);
        w2(nm.length);
        w2(e.extra == null ? 0 : e.extra.length);
        raw.write(nm); pos += nm.length;
        if (e.extra != null) { raw.write(e.extra); pos += e.extra.length; }
        raw.write(body); pos += body.length;
        written.add(e);
        current = null; cur = null;
    }
    public synchronized void write(byte[] b, int off, int len) throws IOException {
        ensureOpen();
        if (off < 0 || len < 0 || off > b.length - len) throw new IndexOutOfBoundsException();
        else if (len == 0) return;
        if (current == null) throw new ZipException("no current ZIP entry");
        cur.write(b, off, len);
    }
    public void write(int b) throws IOException { write(new byte[]{(byte) b}, 0, 1); }
    public void finish() throws IOException {
        ensureOpen();
        if (finished) return;
        if (current != null) closeEntry();
        long cdStart = pos;
        for (ZipEntry e : written) {
            byte[] nm = e.name.getBytes(java.nio.charset.StandardCharsets.UTF_8);
            byte[] cm = e.comment == null ? new byte[0] : e.comment.getBytes(java.nio.charset.StandardCharsets.UTF_8);
            w4(ZipConstants.CENSIG);
            w2(e.method == STORED ? 10 : 20);
            w2(e.method == STORED ? 10 : 20);
            w2(e.flag);
            w2(e.method);
            w4(e.xdostime);
            w4(e.crc);
            w4(e.csize);
            w4(e.size);
            w2(nm.length);
            w2(e.extra == null ? 0 : e.extra.length);
            w2(cm.length);
            w2(0); w2(0); w4(0);
            w4(e.headerOff);
            raw.write(nm); pos += nm.length;
            if (e.extra != null) { raw.write(e.extra); pos += e.extra.length; }
            raw.write(cm); pos += cm.length;
        }
        long cdLen = pos - cdStart;
        byte[] cb = comment == null ? new byte[0] : comment.getBytes(java.nio.charset.StandardCharsets.UTF_8);
        w4(ZipConstants.ENDSIG);
        w2(0); w2(0);
        w2(written.size()); w2(written.size());
        w4(cdLen); w4(cdStart);
        w2(cb.length);
        raw.write(cb); pos += cb.length;
        finished = true;
    }
    public void close() throws IOException {
        if (!closed) { finish(); raw.close(); closed = true; }
    }
    public void flush() throws IOException { raw.flush(); }
}
