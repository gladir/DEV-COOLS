package java.io;
public class PrintWriter extends Writer {
    protected Writer out;
    private final boolean autoFlush;
    public PrintWriter(Writer out) { this(out, false); }
    public PrintWriter(Writer out, boolean autoFlush) { this.out = out; this.autoFlush = autoFlush; }
    public PrintWriter(OutputStream os) { this(new OutputStreamWriter(os), false); }
    public PrintWriter(OutputStream os, boolean autoFlush) { this(new OutputStreamWriter(os), autoFlush); }
    public void write(int c) { try { out.write(c); } catch (IOException e) { } }
    public void write(char[] c, int off, int len) { try { out.write(c, off, len); } catch (IOException e) { } }
    public void write(String s) { try { out.write(s); } catch (IOException e) { } }
    public void write(String s, int off, int len) { try { out.write(s, off, len); } catch (IOException e) { } }
    public void flush() { try { out.flush(); } catch (IOException e) { } }
    public void close() { try { out.close(); } catch (IOException e) { } }
    public boolean checkError() { return false; }
    public void print(String s) { write(s == null ? "null" : s); }
    public void print(Object o) { write(String.valueOf(o)); }
    public void print(char c) { write(c); }
    public void print(int i) { write(String.valueOf(i)); }
    public void print(long l) { write(String.valueOf(l)); }
    public void print(boolean b) { write(b ? "true" : "false"); }
    public void print(double d) { write(String.valueOf(d)); }
    public void print(float f) { write(String.valueOf(f)); }
    public void print(char[] c) { write(new String(c)); }
    public void println() { write("\n"); if (autoFlush) flush(); }
    public void println(String s) { print(s); println(); }
    public void println(Object o) { print(o); println(); }
    public void println(char c) { print(c); println(); }
    public void println(int i) { print(i); println(); }
    public void println(long l) { print(l); println(); }
    public void println(boolean b) { print(b); println(); }
    public void println(double d) { print(d); println(); }
    public void println(float f) { print(f); println(); }
    public void println(char[] c) { print(c); println(); }
    public PrintWriter printf(String f, Object... args) { write(String.format(f, args)); return this; }
    public PrintWriter format(String f, Object... args) { write(String.format(f, args)); return this; }
    public PrintWriter append(CharSequence cs) { write(String.valueOf(cs)); return this; }
    public PrintWriter append(char c) { write(c); return this; }
}
