package java.io;
public class StringReader extends Reader {
    private final String s;
    private int pos;
    public StringReader(String s) { this.s = s; }
    public int read() { return pos < s.length() ? s.charAt(pos++) : -1; }
    public int read(char[] c, int off, int len) {
        if (pos >= s.length()) return -1;
        int n = Math.min(len, s.length() - pos);
        for (int i = 0; i < n; i++) c[off + i] = s.charAt(pos++);
        return n;
    }
    public boolean ready() { return true; }
    public void close() {}
}
