package java.io;
import java.util.stream.Stream;
public class BufferedReader extends Reader {
    private final Reader in;
    private int peeked = -2;
    public BufferedReader(Reader in) { this.in = in; }
    public BufferedReader(Reader in, int sz) { this.in = in; }
    public int read() throws IOException {
        if (peeked != -2) { int c = peeked; peeked = -2; return c; }
        return in.read();
    }
    public int read(char[] c, int off, int len) throws IOException {
        int i = 0;
        while (i < len) { int ch = read(); if (ch < 0) break; c[off + i++] = (char) ch; if (ch == '\n') break; }
        return i == 0 ? -1 : i;
    }
    public String readLine() throws IOException {
        StringBuilder sb = new StringBuilder();
        int c = read();
        if (c < 0) return null;
        while (c >= 0 && c != '\n' && c != '\r') { sb.append((char) c); c = read(); }
        if (c == '\r') { int d = read(); if (d != '\n') peeked = d; }
        return sb.toString();
    }
    public Stream<String> lines() {
        java.util.ArrayList<String> l = new java.util.ArrayList<>();
        try { String s; while ((s = readLine()) != null) l.add(s); } catch (IOException e) { throw new UncheckedIOException(e); }
        return l.stream();
    }
    public boolean ready() throws IOException { return peeked != -2 || in.ready(); }
    public void close() throws IOException { in.close(); }
}
