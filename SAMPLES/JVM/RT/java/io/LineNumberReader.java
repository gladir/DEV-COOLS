package java.io;
public class LineNumberReader extends BufferedReader {
    private int lineNumber = 0;
    private boolean skipLF;
    public LineNumberReader(Reader in) { super(in); }
    public LineNumberReader(Reader in, int sz) { super(in, sz); }
    public void setLineNumber(int lineNumber) { this.lineNumber = lineNumber; }
    public int getLineNumber() { return lineNumber; }
    private boolean inLine;
    public int read() throws IOException {
        int c = super.read();
        if (inLine) return c;
        if (skipLF) { if (c == '\n') c = super.read(); skipLF = false; }
        switch (c) {
            case '\r': skipLF = true;
            case '\n': lineNumber++; return '\n';
        }
        return c;
    }
    public String readLine() throws IOException {
        inLine = true;
        String l;
        try { l = super.readLine(); } finally { inLine = false; }
        if (l != null) lineNumber++;
        return l;
    }
}
