package java.util;
public final class Formatter implements java.io.Closeable, java.io.Flushable {
    private Appendable a;
    private final Locale l;
    public Formatter() { this.a = new StringBuilder(); this.l = Locale.US; }
    public Formatter(Appendable a) { this.a = a == null ? new StringBuilder() : a; this.l = Locale.US; }
    public Formatter(Locale l) { this.a = new StringBuilder(); this.l = l; }
    public Formatter(Appendable a, Locale l) { this.a = a == null ? new StringBuilder() : a; this.l = l; }
    public Appendable out() { return a; }
    public String toString() { return a.toString(); }
    public void flush() { }
    public void close() { }
    public Locale locale() { return l; }
    private void app(String s) { try { a.append(s); } catch (java.io.IOException e) { throw new RuntimeException(e); } }
    public Formatter format(String format, Object... args) { return format(l, format, args); }
    public Formatter format(Locale l, String format, Object... args) {
        int n = format.length();
        int lastIdx = -1;
        int ordinary = 0;
        int i = 0;
        StringBuilder out = new StringBuilder();
        while (i < n) {
            char c = format.charAt(i);
            if (c != '%') { out.append(c); i++; continue; }
            i++;
            if (i >= n) throw new UnknownFormatConversionException("%");
            // [index$][flags][width][.precision]conv
            int start = i;
            int argIndex = -1;
            int j = i;
            while (j < n && Character.isDigit(format.charAt(j))) j++;
            if (j < n && j > i && format.charAt(j) == '$') { argIndex = Integer.parseInt(format.substring(i, j)); i = j + 1; }
            boolean left = false, plus = false, space = false, zero = false, comma = false, paren = false, alt = false, prev = false;
            while (i < n) {
                char f = format.charAt(i);
                if (f == '-') left = true; else if (f == '+') plus = true; else if (f == ' ') space = true;
                else if (f == '0') zero = true; else if (f == ',') comma = true; else if (f == '(') paren = true;
                else if (f == '#') alt = true; else if (f == '<') prev = true; else break;
                i++;
            }
            int width = -1;
            j = i;
            while (j < n && Character.isDigit(format.charAt(j))) j++;
            if (j > i) { width = Integer.parseInt(format.substring(i, j)); i = j; }
            int prec = -1;
            if (i < n && format.charAt(i) == '.') {
                i++; j = i;
                while (j < n && Character.isDigit(format.charAt(j))) j++;
                if (j == i) throw new IllegalFormatPrecisionException(-1);
                prec = Integer.parseInt(format.substring(i, j)); i = j;
            }
            if (i >= n) throw new UnknownFormatConversionException("%");
            char conv = format.charAt(i++);
            boolean upper = false;
            if (conv == 't' || conv == 'T') { i++; out.append("?"); continue; }
            if (conv == 'n') { out.append('\n'); continue; }
            if (conv == '%') { pad(out, "%", width, left, false); continue; }
            Object arg;
            if (prev) arg = args[lastIdx];
            else if (argIndex > 0) { lastIdx = argIndex - 1; if (lastIdx >= args.length) throw new MissingFormatArgumentException("%" + format.substring(start - 0, i)); arg = args[lastIdx]; }
            else {
                lastIdx = ordinary++;
                if (args == null || lastIdx >= args.length) throw new MissingFormatArgumentException("%" + format.substring(start, i));
                arg = args[lastIdx];
            }
            String s;
            if (Character.isUpperCase(conv)) { upper = true; conv = Character.toLowerCase(conv); }
            switch (conv) {
                case 'd': {
                    if (arg == null) { s = "null"; break; }
                    if (!(arg instanceof Integer || arg instanceof Long || arg instanceof Short || arg instanceof Byte || arg instanceof java.math.BigInteger))
                        throw new IllegalFormatConversionException('d', arg.getClass());
                    String digits = arg.toString();
                    boolean neg = digits.startsWith("-");
                    if (neg) digits = digits.substring(1);
                    if (comma) digits = group(digits);
                    s = signed(digits, neg, plus, space, paren, zero, width, left);
                    break;
                }
                case 'x': case 'o': {
                    if (arg == null) { s = "null"; break; }
                    String digits;
                    if (arg instanceof Integer) digits = conv == 'x' ? Integer.toHexString((Integer) arg) : Integer.toOctalString((Integer) arg);
                    else if (arg instanceof Long) digits = conv == 'x' ? Long.toHexString((Long) arg) : Long.toOctalString((Long) arg);
                    else if (arg instanceof Short) digits = conv == 'x' ? Integer.toHexString(((Short) arg) & 0xffff) : Integer.toOctalString(((Short) arg) & 0xffff);
                    else if (arg instanceof Byte) digits = conv == 'x' ? Integer.toHexString(((Byte) arg) & 0xff) : Integer.toOctalString(((Byte) arg) & 0xff);
                    else throw new IllegalFormatConversionException(conv, arg.getClass());
                    if (alt) digits = (conv == 'x' ? "0x" : "0") + digits;
                    if (zero && width > digits.length()) { StringBuilder z = new StringBuilder(); for (int k = digits.length(); k < width; k++) z.append('0'); digits = z + digits; }
                    s = digits;
                    break;
                }
                case 'f': case 'e': case 'g': {
                    if (arg == null) { s = "null"; break; }
                    double d;
                    if (arg instanceof Double) d = (Double) arg;
                    else if (arg instanceof Float) d = ((Float) arg).doubleValue();
                    else if (arg instanceof java.math.BigDecimal) d = ((java.math.BigDecimal) arg).doubleValue();
                    else throw new IllegalFormatConversionException(conv, arg.getClass());
                    if (Double.isNaN(d) || Double.isInfinite(d)) {
                        String t = Double.isNaN(d) ? "NaN" : (d > 0 ? (plus ? "+Infinity" : "Infinity") : (paren ? "(Infinity)" : "-Infinity"));
                        s = t;
                        break;
                    }
                    boolean neg = d < 0 || (d == 0 && 1 / d < 0);
                    double ad = Math.abs(d);
                    String body;
                    if (conv == 'f') {
                        body = VM.fixed(ad, prec < 0 ? 6 : prec);
                        if (comma) { int dot = body.indexOf('.'); body = dot < 0 ? group(body) : group(body.substring(0, dot)) + body.substring(dot); }
                        if (alt && prec == 0) body += ".";
                    } else if (conv == 'e') {
                        body = sci(ad, prec < 0 ? 6 : prec);
                    } else {
                        int p = prec < 0 ? 6 : (prec == 0 ? 1 : prec);
                        if (ad != 0 && (ad < 1e-4 || ad >= Math.pow(10, p))) body = sci(ad, p - 1);
                        else {
                            int mag = ad == 0 ? 0 : (int) Math.floor(Math.log10(ad));
                            body = VM.fixed(ad, Math.max(0, p - 1 - mag));
                            if (comma) { int dot = body.indexOf('.'); body = dot < 0 ? group(body) : group(body.substring(0, dot)) + body.substring(dot); }
                        }
                    }
                    s = signed(body, neg, plus, space, paren, zero, width, left);
                    break;
                }
                case 's': {
                    s = String.valueOf(arg);
                    if (prec >= 0 && prec < s.length()) s = s.substring(0, prec);
                    break;
                }
                case 'c': {
                    if (arg == null) s = "null";
                    else if (arg instanceof Character) s = String.valueOf(((Character) arg).charValue());
                    else if (arg instanceof Integer) s = new String(Character.toChars((Integer) arg));
                    else throw new IllegalFormatConversionException('c', arg.getClass());
                    break;
                }
                case 'b': {
                    s = arg == null ? "false" : (arg instanceof Boolean ? arg.toString() : "true");
                    if (prec >= 0 && prec < s.length()) s = s.substring(0, prec);
                    break;
                }
                case 'h': s = arg == null ? "null" : Integer.toHexString(arg.hashCode()); break;
                default: throw new UnknownFormatConversionException(String.valueOf(conv));
            }
            if (upper) s = s.toUpperCase();
            pad(out, s, width, left, false);
        }
        app(out.toString());
        return this;
    }
    private static void pad(StringBuilder out, String s, int width, boolean left, boolean zero) {
        int padn = width - s.length();
        if (padn <= 0) { out.append(s); return; }
        if (left) { out.append(s); for (int k = 0; k < padn; k++) out.append(' '); }
        else { for (int k = 0; k < padn; k++) out.append(' '); out.append(s); }
    }
    private static String group(String digits) {
        StringBuilder sb = new StringBuilder();
        int n = digits.length();
        for (int i = 0; i < n; i++) {
            if (i > 0 && (n - i) % 3 == 0) sb.append(',');
            sb.append(digits.charAt(i));
        }
        return sb.toString();
    }
    private static String signed(String body, boolean neg, boolean plus, boolean space, boolean paren, boolean zero, int width, boolean left) {
        String pre = neg ? (paren ? "(" : "-") : (plus ? "+" : (space ? " " : ""));
        String suf = neg && paren ? ")" : "";
        if (zero && width > 0) {
            int total = pre.length() + body.length() + suf.length();
            StringBuilder z = new StringBuilder();
            for (int k = total; k < width; k++) z.append('0');
            body = z + body;
        }
        return pre + body + suf;
    }
    private static String sci(double d, int prec) {
        if (d == 0) {
            StringBuilder sb = new StringBuilder("0");
            if (prec > 0) { sb.append('.'); for (int i = 0; i < prec; i++) sb.append('0'); }
            return sb.append("e+00").toString();
        }
        int exp = (int) Math.floor(Math.log10(d));
        double m = d / Math.pow(10, exp);
        if (m >= 10) { m /= 10; exp++; } else if (m < 1) { m *= 10; exp--; }
        String ms = VM.fixed(m, prec);
        if (ms.startsWith("10")) { m /= 10; exp++; ms = VM.fixed(m, prec); }
        String es = Integer.toString(Math.abs(exp));
        if (es.length() < 2) es = "0" + es;
        return ms + "e" + (exp < 0 ? "-" : "+") + es;
    }
}
