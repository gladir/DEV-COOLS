package java.io;
import java.util.Locale;
public class PrintStream extends OutputStream implements Appendable {
    private final OutputStream out;
    private final boolean autoFlush;
    private int fd = -1;
    private boolean err = false;
    public PrintStream(OutputStream out) { this(out, false); }
    public PrintStream(OutputStream out, boolean autoFlush) {
        this.out = out; this.autoFlush = autoFlush;
        if (out instanceof FileOutputStream) { fd = ((FileOutputStream) out).hashCode() == 0 ? -1 : -1; }
    }
    public PrintStream(OutputStream out, boolean autoFlush, String enc) { this(out, autoFlush); }
    public PrintStream(OutputStream out, boolean autoFlush, java.nio.charset.Charset cs) { this(out, autoFlush); }
    private void emit(String s) {
        if (out instanceof FileOutputStream) {
            java.lang.VM.write(((FileOutputStream) out).fdNumber(), s);
        } else {
            try {
                byte[] b = s.getBytes();
                out.write(b, 0, b.length);
            } catch (IOException e) { }
        }
    }
    public void write(int b) { try { out.write(b); } catch (IOException e) { } }
    public void write(byte[] b, int off, int len) { try { out.write(b, off, len); } catch (IOException e) { } }
    public void flush() { try { out.flush(); } catch (IOException e) { } java.lang.VM.flush(); }
    public void close() { flush(); }
    public boolean checkError() { return false; }
    public void print(String s) { emit(s == null ? "null" : s); }
    public void print(Object o) { emit(String.valueOf(o)); }
    public void print(char c) { emit(String.valueOf(c)); }
    public void print(int i) { emit(String.valueOf(i)); }
    public void print(long l) { emit(String.valueOf(l)); }
    public void print(boolean b) { emit(b ? "true" : "false"); }
    public void print(double d) { emit(String.valueOf(d)); }
    public void print(float f) { emit(String.valueOf(f)); }
    public void print(char[] c) { emit(new String(c)); }
    public void println() { emit("\n"); }
    public void println(String s) { emit((s == null ? "null" : s) + "\n"); }
    public void println(Object o) { emit(String.valueOf(o) + "\n"); }
    public void println(char c) { emit(String.valueOf(c) + "\n"); }
    public void println(int i) { emit(String.valueOf(i) + "\n"); }
    public void println(long l) { emit(String.valueOf(l) + "\n"); }
    public void println(boolean b) { emit((b ? "true" : "false") + "\n"); }
    public void println(double d) { emit(String.valueOf(d) + "\n"); }
    public void println(float f) { emit(String.valueOf(f) + "\n"); }
    public void println(char[] c) { emit(new String(c) + "\n"); }
    public PrintStream printf(String format, Object... args) { emit(String.format(format, args)); return this; }
    public PrintStream printf(Locale l, String format, Object... args) { emit(String.format(format, args)); return this; }
    public PrintStream format(String format, Object... args) { emit(String.format(format, args)); return this; }
    public PrintStream append(CharSequence cs) { print(String.valueOf(cs)); return this; }
    public PrintStream append(CharSequence cs, int s, int e) { print(String.valueOf(cs).substring(s, e)); return this; }
    public PrintStream append(char c) { print(c); return this; }
}
