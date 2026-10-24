package java.lang;
public final class StringBuffer implements java.io.Serializable, Comparable<StringBuffer>, CharSequence, Appendable {
    public StringBuffer() {}
    public StringBuffer(String s) { append(s); }
    public StringBuffer(int capacity) { this(); }
    public StringBuffer(CharSequence cs) { append(cs.toString()); }
    public native StringBuffer append(String s);
    public native StringBuffer append(Object o);
    public native StringBuffer append(char c);
    public native StringBuffer append(int i);
    public native StringBuffer append(boolean b);
    public native StringBuffer append(double d);
    public native StringBuffer append(float f);
    public native StringBuffer append(char[] c);
    public native StringBuffer append(char[] c, int off, int len);
    public native StringBuffer append(CharSequence s, int start, int end);
    public StringBuffer append(long l) { return append(Long.toString(l)); }
    public StringBuffer append(CharSequence s) { return append(String.valueOf(s)); }
    public native String toString();
    public native int length();
    public native int capacity();
    public native char charAt(int i);
    public native void setCharAt(int i, char c);
    public native void setLength(int n);
    public native StringBuffer reverse();
    public native StringBuffer deleteCharAt(int i);
    public native StringBuffer delete(int start, int end);
    public native StringBuffer insert(int i, String s);
    public native StringBuffer insert(int i, Object o);
    public native StringBuffer insert(int i, char c);
    public native StringBuffer insert(int i, int v);
    public StringBuffer insert(int i, long v) { return insert(i, Long.toString(v)); }
    public native StringBuffer replace(int start, int end, String s);
    public native int indexOf(String s, int from);
    public native int lastIndexOf(String s, int from);
    public int indexOf(String s) { return indexOf(s, 0); }
    public int lastIndexOf(String s) { return lastIndexOf(s, length()); }
    public native String substring(int start, int end);
    public String substring(int start) { return substring(start, length()); }
    public CharSequence subSequence(int start, int end) { return substring(start, end); }
    public void ensureCapacity(int n) { }
    public boolean isEmpty() { return length() == 0; }
    public int compareTo(StringBuffer o) { return toString().compareTo(o.toString()); }
}
