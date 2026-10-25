package java.io;
public class OutputStreamWriter extends Writer {
    private final OutputStream os;
    public OutputStreamWriter(OutputStream os) { this.os = os; }
    public OutputStreamWriter(OutputStream os, String cs) { this.os = os; }
    public OutputStreamWriter(OutputStream os, java.nio.charset.Charset cs) { this.os = os; }
    public void write(char[] c, int off, int len) throws IOException {
        byte[] b = new String(c, off, len).getBytes();
        os.write(b, 0, b.length);
    }
    public void write(String s) throws IOException { byte[] b = s.getBytes(); os.write(b, 0, b.length); }
    public void flush() throws IOException { os.flush(); }
    public void close() throws IOException { os.flush(); os.close(); }
}
