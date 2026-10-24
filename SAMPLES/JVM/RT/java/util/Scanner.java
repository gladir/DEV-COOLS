package java.util;
import java.io.*;
public final class Scanner implements Iterator<String>, Closeable {
    private final Reader in;
    private int peek = -2;
    private boolean closed;
    public Scanner(InputStream source) { this.in = new InputStreamReader(source); }
    public Scanner(Readable source) { this.in = (Reader) source; }
    public Scanner(String source) { this.in = new StringReader(source); }
    public Scanner(File source) throws FileNotFoundException { this.in = new FileReader(source); }
    private int rd() { if (peek != -2) { int c = peek; peek = -2; return c; } try { return in.read(); } catch (IOException e) { return -1; } }
    private int pk() { if (peek == -2) { try { peek = in.read(); } catch (IOException e) { peek = -1; } } return peek; }
    private void skipWs() { while (true) { int c = pk(); if (c >= 0 && Character.isWhitespace((char) c)) rd(); else break; } }
    public boolean hasNext() { if (tok != null) return true; skipWs(); return pk() >= 0; }
    public String next() {
        if (tok != null) { String t = tok; tok = null; return t; }
        skipWs();
        if (pk() < 0) throw new NoSuchElementException();
        StringBuilder sb = new StringBuilder();
        while (true) { int c = pk(); if (c < 0 || Character.isWhitespace((char) c)) break; sb.append((char) rd()); }
        return sb.toString();
    }
    private String tok;
    private String peekToken() { if (tok == null) { skipWs(); if (pk() < 0) return null; tok = next(); } return tok; }
    private String takeToken() { String t = peekToken(); if (t == null) throw new NoSuchElementException(); tok = null; return t; }
    public boolean hasNextInt() { String t = peekToken(); if (t == null) return false; try { Integer.parseInt(t); return true; } catch (NumberFormatException e) { return false; } }
    public boolean hasNextLong() { String t = peekToken(); if (t == null) return false; try { Long.parseLong(t); return true; } catch (NumberFormatException e) { return false; } }
    public boolean hasNextDouble() { String t = peekToken(); if (t == null) return false; try { Double.parseDouble(t); return true; } catch (NumberFormatException e) { return false; } }
    public int nextInt() { String t = peekToken(); if (t == null) throw new NoSuchElementException(); try { int v = Integer.parseInt(t); tok = null; return v; } catch (NumberFormatException e) { throw new InputMismatchException("For input string: \"" + t + "\""); } }
    public long nextLong() { String t = peekToken(); if (t == null) throw new NoSuchElementException(); try { long v = Long.parseLong(t); tok = null; return v; } catch (NumberFormatException e) { throw new InputMismatchException("For input string: \"" + t + "\""); } }
    public double nextDouble() { String t = peekToken(); if (t == null) throw new NoSuchElementException(); try { double v = Double.parseDouble(t); tok = null; return v; } catch (NumberFormatException e) { throw new InputMismatchException("For input string: \"" + t + "\""); } }
    public float nextFloat() { return (float) nextDouble(); }
    public boolean nextBoolean() { String t = takeToken(); if (t.equalsIgnoreCase("true")) return true; if (t.equalsIgnoreCase("false")) return false; throw new InputMismatchException(t); }
    public boolean hasNextLine() { if (tok != null) return true; return pk() >= 0; }
    public String nextLine() {
        StringBuilder sb = new StringBuilder();
        if (tok != null) { sb.append(tok); tok = null; }
        int c = rd();
        if (c < 0 && sb.length() == 0) throw new NoSuchElementException("No line found");
        while (c >= 0 && c != '\n' && c != '\r') { sb.append((char) c); c = rd(); }
        if (c == '\r' && pk() == '\n') rd();
        return sb.toString();
    }
    public void close() { closed = true; try { in.close(); } catch (IOException e) { } }
    public Scanner useDelimiter(String p) { return this; }
}
