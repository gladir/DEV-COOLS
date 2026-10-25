package java.io;
import java.util.Enumeration;
public class SequenceInputStream extends InputStream {
    private final Enumeration<? extends InputStream> e;
    private InputStream in;
    public SequenceInputStream(Enumeration<? extends InputStream> e) {
        this.e = e;
        peekNextStream();
    }
    public SequenceInputStream(InputStream s1, InputStream s2) {
        this(java.util.Collections.enumeration(java.util.Arrays.asList(s1, s2)));
    }
    final void nextStream() throws IOException {
        if (in != null) in.close();
        peekNextStream();
    }
    private void peekNextStream() {
        if (e.hasMoreElements()) {
            in = (InputStream) e.nextElement();
            if (in == null) throw new NullPointerException();
        } else in = null;
    }
    public int available() throws IOException { return in == null ? 0 : in.available(); }
    public int read() throws IOException {
        while (in != null) {
            int c = in.read();
            if (c != -1) return c;
            nextStream();
        }
        return -1;
    }
    public int read(byte[] b, int off, int len) throws IOException {
        if (in == null) return -1;
        else if (len == 0) return 0;
        do {
            int n = in.read(b, off, len);
            if (n > 0) return n;
            nextStream();
        } while (in != null);
        return -1;
    }
    public void close() throws IOException {
        do { nextStream(); } while (in != null);
    }
}
