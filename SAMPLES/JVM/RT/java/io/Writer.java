package java.io;
public abstract class Writer implements Appendable, Closeable, Flushable {
    protected Writer() {}
    public void write(int c) throws IOException { write(new char[] { (char) c }, 0, 1); }
    public void write(char[] c) throws IOException { write(c, 0, c.length); }
    public abstract void write(char[] c, int off, int len) throws IOException;
    public void write(String s) throws IOException { write(s, 0, s.length()); }
    public void write(String s, int off, int len) throws IOException { write(s.substring(off, off + len).toCharArray(), 0, len); }
    public Writer append(CharSequence cs) throws IOException { write(String.valueOf(cs)); return this; }
    public Writer append(CharSequence cs, int s, int e) throws IOException { write(String.valueOf(cs).substring(s, e)); return this; }
    public Writer append(char c) throws IOException { write(c); return this; }
    public abstract void flush() throws IOException;
    public abstract void close() throws IOException;
}
