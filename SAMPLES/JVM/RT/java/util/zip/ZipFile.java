package java.util.zip;
import java.io.*;
import java.util.*;
import java.util.stream.Stream;
public class ZipFile implements Closeable {
    public static final int OPEN_READ = 0x1;
    public static final int OPEN_DELETE = 0x4;
    private final String name;
    private RandomAccessFile raf;
    private final LinkedHashMap<String, ZipEntry> entries = new LinkedHashMap<>();
    private String comment;
    private boolean closed;
    public ZipFile(String name) throws IOException { this(new File(name), OPEN_READ); }
    public ZipFile(File file, int mode) throws IOException {
        this.name = file.getPath();
        if (!file.exists()) throw new FileNotFoundException(name + " (No such file or directory)");
        raf = new RandomAccessFile(file, "r");
        try { readCentral(); } catch (IOException e) { raf.close(); throw e; }
    }
    public ZipFile(File file) throws IOException { this(file, OPEN_READ); }
    private static int u2(byte[] b, int p) { return (b[p] & 255) | ((b[p + 1] & 255) << 8); }
    private static long u4(byte[] b, int p) { return ((long) (b[p] & 255)) | ((long) (b[p + 1] & 255) << 8) | ((long) (b[p + 2] & 255) << 16) | ((long) (b[p + 3] & 255) << 24); }
    private void readCentral() throws IOException {
        long len = raf.length();
        int tail = (int) Math.min(len, 65557);
        byte[] t = new byte[tail];
        raf.seek(len - tail);
        raf.readFully(t);
        int k = tail - 22;
        while (k >= 0 && u4(t, k) != ZipConstants.ENDSIG) k--;
        if (k < 0) throw new ZipException("zip END header not found");
        int n = u2(t, k + 10);
        long cdOff = u4(t, k + 16);
        int cl = u2(t, k + 20);
        comment = cl > 0 ? new String(t, k + 22, cl, java.nio.charset.StandardCharsets.UTF_8) : null;
        long cdLen = u4(t, k + 12);
        byte[] cd = new byte[(int) cdLen];
        raf.seek(cdOff);
        raf.readFully(cd);
        int p = 0;
        for (int i = 0; i < n && p + 46 <= cd.length; i++) {
            if (u4(cd, p) != ZipConstants.CENSIG) throw new ZipException("invalid CEN header (bad signature)");
            int nl = u2(cd, p + 28), el = u2(cd, p + 30), cml = u2(cd, p + 32);
            ZipEntry e = new ZipEntry(new String(cd, p + 46, nl, java.nio.charset.StandardCharsets.UTF_8));
            e.flag = u2(cd, p + 8);
            e.method = u2(cd, p + 10);
            e.xdostime = u4(cd, p + 12);
            e.crc = u4(cd, p + 16);
            e.csize = u4(cd, p + 20);
            e.size = u4(cd, p + 24);
            e.headerOff = u4(cd, p + 42);
            if (el > 0) e.extra = Arrays.copyOfRange(cd, p + 46 + nl, p + 46 + nl + el);
            if (cml > 0) e.comment = new String(cd, p + 46 + nl + el, cml, java.nio.charset.StandardCharsets.UTF_8);
            entries.put(e.name, e);
            p += 46 + nl + el + cml;
        }
    }
    private void ensureOpen() { if (closed) throw new IllegalStateException("zip file closed"); }
    public String getComment() { ensureOpen(); return comment; }
    public ZipEntry getEntry(String name) {
        Objects.requireNonNull(name, "name");
        ensureOpen();
        ZipEntry e = entries.get(name);
        if (e == null && !name.endsWith("/")) e = entries.get(name + "/");
        return e == null ? null : (ZipEntry) newEntry(e);
    }
    ZipEntry newEntry(ZipEntry e) { ZipEntry c = new ZipEntry(e); c.headerOff = e.headerOff; return c; }
    byte[] data(ZipEntry e) throws IOException {
        byte[] hdr = new byte[30];
        raf.seek(e.headerOff);
        raf.readFully(hdr);
        if (u4(hdr, 0) != ZipConstants.LOCSIG) throw new ZipException("invalid LOC header (bad signature)");
        long off = e.headerOff + 30 + u2(hdr, 26) + u2(hdr, 28);
        byte[] raw = new byte[(int) e.csize];
        raf.seek(off);
        raf.readFully(raw);
        if (e.method == ZipEntry.STORED) return raw;
        int[] consumed = new int[1];
        byte[] res = ZipSupport.inflate0(raw, 0, raw.length, consumed);
        if (res == null || consumed[0] < 0) throw new ZipException("invalid block type");
        return res;
    }
    public InputStream getInputStream(ZipEntry entry) throws IOException {
        Objects.requireNonNull(entry, "entry");
        ensureOpen();
        ZipEntry e = entries.get(entry.name);
        if (e == null) return null;
        return new ByteArrayInputStream(data(e));
    }
    public String getName() { return name; }
    public Enumeration<? extends ZipEntry> entries() {
        ensureOpen();
        final Iterator<ZipEntry> it = new ArrayList<>(entries.values()).iterator();
        return new Enumeration<ZipEntry>() {
            public boolean hasMoreElements() { return it.hasNext(); }
            public ZipEntry nextElement() { return newEntry(it.next()); }
        };
    }
    public Stream<? extends ZipEntry> stream() {
        ensureOpen();
        List<ZipEntry> l = new ArrayList<>();
        for (ZipEntry e : entries.values()) l.add(newEntry(e));
        return l.stream();
    }
    public int size() { ensureOpen(); return entries.size(); }
    public void close() throws IOException {
        if (!closed) { closed = true; raf.close(); }
    }
}
