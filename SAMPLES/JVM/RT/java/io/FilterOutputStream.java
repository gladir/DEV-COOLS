package java.io;
public class FilterOutputStream extends OutputStream {
    protected OutputStream out;
    private boolean closed;
    public FilterOutputStream(OutputStream out) { this.out = out; }
    public void write(int b) throws IOException { out.write(b); }
    public void write(byte[] b) throws IOException { write(b, 0, b.length); }
    public void write(byte[] b, int off, int len) throws IOException {
        if ((off | len | (b.length - (len + off)) | (off + len)) < 0) throw new IndexOutOfBoundsException();
        for (int i = 0; i < len; i++) write(b[off + i]);
    }
    public void flush() throws IOException { out.flush(); }
    public void close() throws IOException {
        if (closed) return;
        closed = true;
        Throwable flushException = null;
        try { flush(); } catch (Throwable e) { flushException = e; throw e; }
        finally {
            try { out.close(); } catch (Throwable closeException) {
                if (flushException != closeException && flushException != null) closeException.addSuppressed(flushException);
                throw closeException;
            }
        }
    }
}
