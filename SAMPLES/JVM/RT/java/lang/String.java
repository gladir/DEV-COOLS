package java.lang;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;
import java.nio.charset.Charset;
public final class String implements java.io.Serializable, Comparable<String>, CharSequence {
    private static final long serialVersionUID = -6849794470754667710L;
    public static final Comparator<String> CASE_INSENSITIVE_ORDER = (a, b) -> a.compareToIgnoreCase(b);
    public String() { }
    public String(String original) { init1(original); }
    public String(char[] value) { init2(value); }
    public String(char[] value, int offset, int count) { init3(value, offset, count); }
    public String(byte[] bytes) { init4(bytes); }
    public String(byte[] bytes, int offset, int length) { init5(bytes, offset, length, false); }
    public String(byte[] bytes, Charset cs) { init5(bytes, 0, bytes.length, cs.isLatin1()); }
    public String(byte[] bytes, String charsetName) { init5(bytes, 0, bytes.length, charsetName.equalsIgnoreCase("ISO-8859-1") || charsetName.equalsIgnoreCase("US-ASCII")); }
    public String(byte[] bytes, int offset, int length, Charset cs) { init5(bytes, offset, length, cs.isLatin1()); }
    public String(StringBuilder sb) { init1(sb.toString()); }
    public String(StringBuffer sb) { init1(sb.toString()); }
    public String(int[] codePoints, int offset, int count) {
        StringBuilder sb = new StringBuilder();
        for (int i = offset; i < offset + count; i++) sb.appendCodePoint(codePoints[i]);
        init1(sb.toString());
    }
    private native void init1(String s);
    private native void init2(char[] c);
    private native void init3(char[] c, int off, int n);
    private native void init4(byte[] b);
    private native void init5(byte[] b, int off, int n, boolean latin1);
    public native int length();
    public native boolean isEmpty();
    public native char charAt(int index);
    public native int hashCode();
    public native boolean equals(Object o);
    public native int compareTo(String o);
    public native int compareToIgnoreCase(String o);
    public native boolean equalsIgnoreCase(String o);
    public native String substring(int begin);
    public native String substring(int begin, int end);
    public CharSequence subSequence(int begin, int end) { return substring(begin, end); }
    public native int indexOf(int ch, int from);
    public native int lastIndexOf(int ch, int from);
    public native int indexOf(String s, int from);
    public native int lastIndexOf(String s, int from);
    public int indexOf(int ch) { return indexOf(ch, 0); }
    public int indexOf(String s) { return indexOf(s, 0); }
    public int lastIndexOf(int ch) { return lastIndexOf(ch, length() - 1); }
    public int lastIndexOf(String s) { return lastIndexOf(s, length()); }
    public native boolean startsWith(String p, int off);
    public boolean startsWith(String p) { return startsWith(p, 0); }
    public native boolean endsWith(String p);
    public native String concat(String s);
    public native String toUpperCase();
    public native String toLowerCase();
    public String toUpperCase(java.util.Locale l) { return toUpperCase(); }
    public String toLowerCase(java.util.Locale l) { return toLowerCase(); }
    public native String trim();
    public native String strip();
    public native String stripLeading();
    public native String stripTrailing();
    public native String replace(char a, char b);
    public native String replace(CharSequence a, CharSequence b);
    public native char[] toCharArray();
    public native String intern();
    public native String repeat(int n);
    public native int codePointAt(int i);
    private native byte[] getBytes0(boolean latin1);
    public byte[] getBytes() { return getBytes0(false); }
    public byte[] getBytes(Charset cs) { return getBytes0(cs.isLatin1()); }
    public byte[] getBytes(String charsetName) { return getBytes0(charsetName.equalsIgnoreCase("ISO-8859-1") || charsetName.equalsIgnoreCase("US-ASCII")); }
    public boolean contains(CharSequence s) { return indexOf(s.toString(), 0) >= 0; }
    public boolean contentEquals(CharSequence cs) { return equals(cs.toString()); }
    public String toString() { return this; }
    public boolean isBlank() { return strip().isEmpty(); }
    public boolean matches(String regex) { return java.util.regex.Pattern.matches(regex, this); }
    public String replaceAll(String regex, String repl) { return java.util.regex.Pattern.compile(regex).matcher(this).replaceAll(repl); }
    public String replaceFirst(String regex, String repl) { return java.util.regex.Pattern.compile(regex).matcher(this).replaceFirst(repl); }
    public String[] split(String regex) { return split(regex, 0); }
    public String[] split(String regex, int limit) {
        List<String> list = new ArrayList<>();
        int n = regex.length();
        boolean simple = false;
        if (n == 1 && ".$|()[{^?*+\\".indexOf(regex.charAt(0)) == -1) simple = true;
        else if (n == 2 && regex.charAt(0) == '\\' && !Character.isLetterOrDigit(regex.charAt(1))) { regex = regex.substring(1); n = 1; simple = true; }
        if (simple) {
            int off = 0, next;
            boolean limited = limit > 0;
            while ((next = indexOf(regex, off)) != -1) {
                if (!limited || list.size() < limit - 1) {
                    list.add(substring(off, next));
                    off = next + n;
                } else break;
            }
            if (off == 0 && list.isEmpty()) return new String[] { this };
            list.add(substring(off, length()));
        } else {
            java.util.regex.Matcher m = java.util.regex.Pattern.compile(regex).matcher(this);
            int index = 0;
            boolean limited = limit > 0;
            while (m.find()) {
                if (!limited || list.size() < limit - 1) {
                    if (index == 0 && index == m.start() && m.start() == m.end()) continue;
                    list.add(substring(index, m.start()));
                    index = m.end();
                } else if (list.size() == limit - 1) {
                    break;
                }
            }
            if (index == 0 && list.isEmpty()) return new String[] { this };
            list.add(substring(index, length()));
        }
        int size = list.size();
        if (limit == 0) while (size > 0 && list.get(size - 1).isEmpty()) size--;
        String[] r = new String[size];
        for (int i = 0; i < size; i++) r[i] = list.get(i);
        return r;
    }
    public java.util.stream.IntStream chars() {
        int[] a = new int[length()];
        for (int i = 0; i < a.length; i++) a[i] = charAt(i);
        return java.util.stream.IntStream.of(a);
    }
    public java.util.stream.Stream<String> lines() {
        List<String> l = new ArrayList<>();
        int i = 0, n = length();
        while (i < n) {
            int j = i;
            while (j < n && charAt(j) != '\n' && charAt(j) != '\r') j++;
            l.add(substring(i, j));
            if (j < n && charAt(j) == '\r' && j + 1 < n && charAt(j + 1) == '\n') j++;
            i = j + 1;
        }
        return l.stream();
    }
    public String indent(int n) {
        StringBuilder sb = new StringBuilder();
        for (String line : lines().toList()) {
            if (n > 0) sb.append(" ".repeat(n)).append(line);
            else {
                int k = 0;
                while (k < -n && k < line.length() && Character.isWhitespace(line.charAt(k))) k++;
                sb.append(line.substring(k));
            }
            sb.append('\n');
        }
        return sb.toString();
    }
    public String stripIndent() { return this; }
    public String translateEscapes() { return this; }
    public int codePointCount(int b, int e) { int c = 0; for (int i = b; i < e; i++) { c++; if (Character.isHighSurrogate(charAt(i)) && i + 1 < e) i++; } return c; }
    public java.util.stream.IntStream codePoints() {
        java.util.ArrayList<Integer> l = new java.util.ArrayList<>();
        for (int i = 0; i < length(); i++) { int cp = codePointAt(i); l.add(cp); if (cp >= 0x10000) i++; }
        int[] a = new int[l.size()];
        for (int i = 0; i < a.length; i++) a[i] = l.get(i);
        return java.util.stream.IntStream.of(a);
    }
    public void getChars(int srcBegin, int srcEnd, char[] dst, int dstBegin) {
        for (int i = srcBegin; i < srcEnd; i++) dst[dstBegin++] = charAt(i);
    }
    public boolean regionMatches(int toffset, String other, int ooffset, int len) {
        return regionMatches(false, toffset, other, ooffset, len);
    }
    public boolean regionMatches(boolean ignoreCase, int toffset, String other, int ooffset, int len) {
        if (ooffset < 0 || toffset < 0 || toffset > (long) length() - len || ooffset > (long) other.length() - len) return false;
        for (int i = 0; i < len; i++) {
            char a = charAt(toffset + i), b = other.charAt(ooffset + i);
            if (a == b) continue;
            if (ignoreCase && Character.toLowerCase(Character.toUpperCase(a)) == Character.toLowerCase(Character.toUpperCase(b))) continue;
            return false;
        }
        return true;
    }
    public String formatted(Object... args) { return format(this, args); }
    public static String format(String fmt, Object... args) { return new java.util.Formatter().format(fmt, args).toString(); }
    public static String format(java.util.Locale l, String fmt, Object... args) { return format(fmt, args); }
    public static String valueOf(Object o) { return o == null ? "null" : o.toString(); }
    public static String valueOf(char[] c) { return new String(c); }
    public static String valueOf(char[] c, int off, int n) { return new String(c, off, n); }
    public static String copyValueOf(char[] c) { return new String(c); }
    public static String copyValueOf(char[] c, int off, int n) { return new String(c, off, n); }
    public static native String valueOf(char c);
    public static native String valueOf(int i);
    public static String valueOf(long l) { return Long.toString(l); }
    public static String valueOf(boolean b) { return b ? "true" : "false"; }
    public static native String valueOf(double d);
    public static native String valueOf(float f);
    public static String join(CharSequence delim, CharSequence... elems) {
        StringBuilder sb = new StringBuilder();
        for (int i = 0; i < elems.length; i++) { if (i > 0) sb.append(delim); sb.append(elems[i]); }
        return sb.toString();
    }
    public static String join(CharSequence delim, Iterable<? extends CharSequence> elems) {
        StringBuilder sb = new StringBuilder();
        boolean first = true;
        for (CharSequence cs : elems) { if (!first) sb.append(delim); first = false; sb.append(cs); }
        return sb.toString();
    }
}
