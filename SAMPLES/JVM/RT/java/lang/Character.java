package java.lang;
public final class Character implements java.io.Serializable, Comparable<Character> {
    public static final char MIN_VALUE = '\u0000';
    public static final char MAX_VALUE = '￿';
    public static final int MIN_RADIX = 2;
    public static final int MAX_RADIX = 36;
    public static final int SIZE = 16;
    public static final int BYTES = 2;
    public static final Class<Character> TYPE = (Class<Character>) Class.getPrimitiveClass("char");
    private final char value;
    private static final Character[] cache = new Character[128];
    public Character(char value) { this.value = value; }
    public static Character valueOf(char c) {
        if (c < 128) {
            Character r = cache[c];
            if (r == null) { r = new Character(c); cache[c] = r; }
            return r;
        }
        return new Character(c);
    }
    public char charValue() { return value; }
    public int hashCode() { return value; }
    public static int hashCode(char v) { return v; }
    public boolean equals(Object o) { return o instanceof Character && ((Character) o).value == value; }
    public String toString() { return String.valueOf(value); }
    public static String toString(char c) { return String.valueOf(c); }
    public static String toString(int cp) { return String.valueOf(toChars(cp)); }
    public int compareTo(Character o) { return value - o.value; }
    public static int compare(char x, char y) { return x - y; }
    public static native boolean isLetter(int c);
    public static native boolean isDigit(int c);
    public static native boolean isWhitespace(int c);
    public static native boolean isUpperCase(int c);
    public static native boolean isLowerCase(int c);
    public static native int toUpperCase(int c);
    public static native int toLowerCase(int c);
    public static boolean isLetter(char c) { return isLetter((int) c); }
    public static boolean isDigit(char c) { return isDigit((int) c); }
    public static boolean isWhitespace(char c) { return isWhitespace((int) c); }
    public static boolean isSpaceChar(char c) { return c == ' ' || c == 0xA0 || (c >= 0x2000 && c <= 0x200A) || c == 0x3000; }
    public static boolean isUpperCase(char c) { return isUpperCase((int) c); }
    public static boolean isLowerCase(char c) { return isLowerCase((int) c); }
    public static char toUpperCase(char c) { return (char) toUpperCase((int) c); }
    public static char toLowerCase(char c) { return (char) toLowerCase((int) c); }
    public static boolean isLetterOrDigit(char c) { return isLetter((int) c) || isDigit((int) c); }
    public static boolean isLetterOrDigit(int c) { return isLetter(c) || isDigit(c); }
    public static boolean isAlphabetic(int c) { return isLetter(c); }
    public static boolean isJavaIdentifierStart(char c) { return isLetter(c) || c == '_' || c == '$'; }
    public static boolean isJavaIdentifierPart(char c) { return isLetterOrDigit(c) || c == '_' || c == '$'; }
    public static boolean isISOControl(char c) { return c <= 0x1F || (c >= 0x7F && c <= 0x9F); }
    public static boolean isSurrogate(char c) { return c >= 0xD800 && c <= 0xDFFF; }
    public static boolean isHighSurrogate(char c) { return c >= 0xD800 && c <= 0xDBFF; }
    public static boolean isLowSurrogate(char c) { return c >= 0xDC00 && c <= 0xDFFF; }
    public static boolean isSupplementaryCodePoint(int cp) { return cp >= 0x10000 && cp <= 0x10FFFF; }
    public static boolean isValidCodePoint(int cp) { return cp >= 0 && cp <= 0x10FFFF; }
    public static int charCount(int cp) { return cp >= 0x10000 ? 2 : 1; }
    public static int toCodePoint(char hi, char lo) { return ((hi - 0xD800) << 10) + (lo - 0xDC00) + 0x10000; }
    public static char[] toChars(int cp) {
        if (cp < 0x10000) return new char[] { (char) cp };
        cp -= 0x10000;
        return new char[] { (char) (0xD800 + (cp >> 10)), (char) (0xDC00 + (cp & 0x3FF)) };
    }
    public static int digit(char c, int radix) { return digit((int) c, radix); }
    public static int digit(int c, int radix) {
        int v = -1;
        if (c >= '0' && c <= '9') v = c - '0';
        else if (c >= 'a' && c <= 'z') v = c - 'a' + 10;
        else if (c >= 'A' && c <= 'Z') v = c - 'A' + 10;
        else if (c >= 0xFF10 && c <= 0xFF19) v = c - 0xFF10;
        return v < radix ? v : -1;
    }
    public static char forDigit(int d, int radix) {
        if (d >= radix || d < 0 || radix < 2 || radix > 36) return '\0';
        return (char) (d < 10 ? '0' + d : 'a' - 10 + d);
    }
    public static int getNumericValue(char c) { int d = digit(c, 36); return d; }
    public static int getType(char c) { return isUpperCase(c) ? 1 : isLowerCase(c) ? 2 : isDigit(c) ? 9 : 0; }
    public static char reverseBytes(char c) { return (char) (((c & 0xFF00) >> 8) | (c << 8)); }
}
