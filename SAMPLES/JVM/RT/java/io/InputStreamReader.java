package java.io;
public class InputStreamReader extends Reader {
    private final InputStream in;
    private int pending = -1;
    public InputStreamReader(InputStream in) { this.in = in; }
    public InputStreamReader(InputStream in, String cs) { this.in = in; }
    public InputStreamReader(InputStream in, java.nio.charset.Charset cs) { this.in = in; }
    public int read() throws IOException {
        if (pending >= 0) { int c = pending; pending = -1; return c; }
        int b = in.read();
        if (b < 0x80) return b;
        int n, cp;
        if ((b & 0xE0) == 0xC0) { n = 1; cp = b & 0x1F; }
        else if ((b & 0xF0) == 0xE0) { n = 2; cp = b & 0x0F; }
        else { n = 3; cp = b & 0x07; }
        for (int i = 0; i < n; i++) { int c = in.read(); if (c < 0) break; cp = (cp << 6) | (c & 0x3F); }
        if (cp >= 0x10000) {
            cp -= 0x10000;
            pending = 0xDC00 + (cp & 0x3FF);
            return 0xD800 + (cp >> 10);
        }
        return cp;
    }
    public int read(char[] c, int off, int len) throws IOException {
        int i = 0;
        while (i < len) { int ch = read(); if (ch < 0) break; c[off + i++] = (char) ch; if (in.available() <= 0 && i > 0 && ch == '\n') break; }
        return i == 0 ? -1 : i;
    }
    public boolean ready() throws IOException { return in.available() > 0; }
    public void close() throws IOException { in.close(); }
}
