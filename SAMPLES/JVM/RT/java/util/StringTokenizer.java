package java.util;
public class StringTokenizer implements Enumeration<Object> {
    private int currentPosition, maxPosition;
    private final String str, delimiters;
    private final boolean retDelims;
    public StringTokenizer(String str, String delim, boolean returnDelims) { this.str = str; delimiters = delim; retDelims = returnDelims; maxPosition = str.length(); }
    public StringTokenizer(String str, String delim) { this(str, delim, false); }
    public StringTokenizer(String str) { this(str, " \t\n\r\f", false); }
    private int skipDelimiters(int startPos) {
        int position = startPos;
        while (!retDelims && position < maxPosition) { if (delimiters.indexOf(str.charAt(position)) < 0) break; position++; }
        return position;
    }
    private int scanToken(int startPos) {
        int position = startPos;
        while (position < maxPosition) { if (delimiters.indexOf(str.charAt(position)) >= 0) break; position++; }
        if (retDelims && (startPos == position)) { if (delimiters.indexOf(str.charAt(position)) >= 0) position++; }
        return position;
    }
    public boolean hasMoreTokens() { return skipDelimiters(currentPosition) < maxPosition; }
    public String nextToken() {
        currentPosition = skipDelimiters(currentPosition);
        if (currentPosition >= maxPosition) throw new NoSuchElementException();
        int start = currentPosition;
        currentPosition = scanToken(currentPosition);
        return str.substring(start, currentPosition);
    }
    public String nextToken(String delim) { return nextToken(); }
    public boolean hasMoreElements() { return hasMoreTokens(); }
    public Object nextElement() { return nextToken(); }
    public int countTokens() {
        int count = 0, currpos = currentPosition;
        while (currpos < maxPosition) { currpos = skipDelimiters(currpos); if (currpos >= maxPosition) break; currpos = scanToken(currpos); count++; }
        return count;
    }
}
