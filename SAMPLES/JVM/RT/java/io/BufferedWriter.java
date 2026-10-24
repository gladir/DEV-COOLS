package java.io;
public class BufferedWriter extends Writer {
    private final Writer out;
    public BufferedWriter(Writer out) { this.out = out; }
    public BufferedWriter(Writer out, int sz) { this.out = out; }
    public void write(char[] c, int off, int len) throws IOException { out.write(c, off, len); }
    public void write(String s) throws IOException { out.write(s); }
    public void newLine() throws IOException { out.write("\n"); }
    public void flush() throws IOException { out.flush(); }
    public void close() throws IOException { out.flush(); out.close(); }
}
