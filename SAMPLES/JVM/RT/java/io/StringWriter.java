package java.io;
public class StringWriter extends Writer {
    private final StringBuilder buf = new StringBuilder();
    public StringWriter() {}
    public StringWriter(int n) {}
    public void write(int c) { buf.append((char) c); }
    public void write(char[] c, int off, int len) { buf.append(c, off, len); }
    public void write(String s) { buf.append(s); }
    public void write(String s, int off, int len) { buf.append(s, off, off + len); }
    public StringWriter append(CharSequence cs) { buf.append(String.valueOf(cs)); return this; }
    public StringWriter append(char c) { buf.append(c); return this; }
    public String toString() { return buf.toString(); }
    public StringBuffer getBuffer() { return new StringBuffer(buf.toString()); }
    public void flush() {}
    public void close() {}
}
