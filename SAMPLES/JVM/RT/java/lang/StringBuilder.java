package java.lang;
public final class StringBuilder implements java.io.Serializable, Comparable<StringBuilder>, CharSequence, Appendable {
    private static final long serialVersionUID = 4383685877147921099L;
    private void writeObject(java.io.ObjectOutputStream s) throws java.io.IOException {
        s.defaultWriteObject();
        s.writeInt(length());
        char[] val = new char[Math.max(length(), 16)];
        toString().getChars(0, length(), val, 0);
        s.writeObject(val);
    }
    private void readObject(java.io.ObjectInputStream s) throws java.io.IOException, ClassNotFoundException {
        s.defaultReadObject();
        int count = s.readInt();
        char[] val = (char[]) s.readObject();
        setLength(0);
        append(val, 0, count);
    }
    public StringBuilder() {}
    public StringBuilder(String s) { append(s); }
    public StringBuilder(int capacity) { this(); }
    public StringBuilder(CharSequence cs) { append(cs.toString()); }
    public native StringBuilder append(String s);
    public native StringBuilder append(Object o);
    public native StringBuilder append(char c);
    public native StringBuilder append(int i);
    public native StringBuilder append(boolean b);
    public native StringBuilder append(double d);
    public native StringBuilder append(float f);
    public native StringBuilder append(char[] c);
    public native StringBuilder append(char[] c, int off, int len);
    public native StringBuilder append(CharSequence s, int start, int end);
    public StringBuilder append(long l) { return append(Long.toString(l)); }
    public StringBuilder append(StringBuffer sb) { return append(String.valueOf(sb)); }
    public StringBuilder append(CharSequence s) { return append(String.valueOf(s)); }
    public StringBuilder appendCodePoint(int cp) { return append(String.valueOf(Character.toChars(cp))); }
    public native String toString();
    public native int length();
    public native int capacity();
    public native char charAt(int i);
    public native void setCharAt(int i, char c);
    public native void setLength(int n);
    public native StringBuilder reverse();
    public native StringBuilder deleteCharAt(int i);
    public native StringBuilder delete(int start, int end);
    public native StringBuilder insert(int i, String s);
    public native StringBuilder insert(int i, Object o);
    public native StringBuilder insert(int i, char c);
    public native StringBuilder insert(int i, int v);
    public StringBuilder insert(int i, long v) { return insert(i, Long.toString(v)); }
    public StringBuilder insert(int i, boolean v) { return insert(i, String.valueOf(v)); }
    public StringBuilder insert(int i, double v) { return insert(i, String.valueOf(v)); }
    public StringBuilder insert(int i, char[] v) { return insert(i, String.valueOf(v)); }
    public native StringBuilder replace(int start, int end, String s);
    public native int indexOf(String s, int from);
    public native int lastIndexOf(String s, int from);
    public int indexOf(String s) { return indexOf(s, 0); }
    public int lastIndexOf(String s) { return lastIndexOf(s, length()); }
    public native String substring(int start, int end);
    public String substring(int start) { return substring(start, length()); }
    public CharSequence subSequence(int start, int end) { return substring(start, end); }
    public void ensureCapacity(int n) { }
    public void trimToSize() { }
    public boolean isEmpty() { return length() == 0; }
    public int compareTo(StringBuilder o) { return toString().compareTo(o.toString()); }
    public java.util.stream.IntStream chars() { return toString().chars(); }
    public void getChars(int srcBegin, int srcEnd, char[] dst, int dstBegin) {
        for (int i = srcBegin; i < srcEnd; i++) dst[dstBegin++] = charAt(i);
    }
}
