package java.util.zip;
import java.io.*;
public class GZIPInputStream extends InflaterInputStream {
    protected CRC32 crc = new CRC32();
    protected boolean eos;
    private boolean closed = false;
    public static final int GZIP_MAGIC = 0x8b1f;
    private static final int FHCRC = 2, FEXTRA = 4, FNAME = 8, FCOMMENT = 16;
    public GZIPInputStream(InputStream in, int size) throws IOException {
        super(in, new Inflater(true), size);
        usesDefaultInflater = true;
        readHeader(in);
    }
    public GZIPInputStream(InputStream in) throws IOException { this(in, 512); }
    public int read(byte[] buf, int off, int len) throws IOException {
        if (closed) throw new IOException("Stream closed");
        if (eos) return -1;
        int n = super.read(buf, off, len);
        if (n == -1) {
            if (readTrailer()) eos = true;
            else return this.read(buf, off, len);
        } else crc.update(buf, off, n);
        return n;
    }
    public void close() throws IOException {
        if (!closed) { super.close(); eos = true; closed = true; }
    }
    private int readUByte(InputStream in) throws IOException {
        int b = in.read();
        if (b == -1) throw new EOFException();
        return b;
    }
    private int readUShort(InputStream in) throws IOException { int b = readUByte(in); return (readUByte(in) << 8) | b; }
    private long readUInt(InputStream in) throws IOException { long s = readUShort(in); return ((long) readUShort(in) << 16) | s; }
    private int readHeader(InputStream this_in) throws IOException {
        CheckedInputStream in = new CheckedInputStream(this_in, crc);
        crc.reset();
        if (readUShort(in) != GZIP_MAGIC) throw new ZipException("Not in GZIP format");
        if (readUByte(in) != 8) throw new ZipException("Unsupported compression method");
        int flg = readUByte(in);
        for (int i = 0; i < 6; i++) readUByte(in);
        int n = 2 + 2 + 6;
        if ((flg & FEXTRA) == FEXTRA) {
            int m = readUShort(in);
            for (int i = 0; i < m; i++) readUByte(in);
            n += m + 2;
        }
        if ((flg & FNAME) == FNAME) { do { n++; } while (readUByte(in) != 0); }
        if ((flg & FCOMMENT) == FCOMMENT) { do { n++; } while (readUByte(in) != 0); }
        if ((flg & FHCRC) == FHCRC) {
            int v = (int) crc.getValue() & 0xffff;
            if (readUShort(in) != v) throw new ZipException("Corrupt GZIP header");
            n += 2;
        }
        crc.reset();
        return n;
    }
    private boolean readTrailer() throws IOException {
        InputStream in = this.in;
        int n = inf.getRemaining();
        if (n > 0) in = new SequenceInputStream(new ByteArrayInputStream(buf, len - n, n), this.in);
        if ((readUInt(in) != crc.getValue()) || (readUInt(in) != (inf.getBytesWritten() & 0xffffffffL))) throw new ZipException("Corrupt GZIP trailer");
        if (this.in.available() > 0 || n > 26) {
            int m = 8;
            try { m += readHeader(in); } catch (IOException ze) { return true; }
            inf.reset();
            if (n > m) inf.setInput(buf, len - n + m, n - m);
            return false;
        }
        return true;
    }
    private byte[] rest() { return buf; }
}
