package java.text;
import java.math.*;
import java.util.Locale;
public class DecimalFormat extends NumberFormat {
    private static final long serialVersionUID = 864413376551465018L;
    private String prefix = "", suffix = "";
    private int groupSize = 0;
    private boolean percent;
    private char dec = '.', grp = ',';
    private String pattern;
    public DecimalFormat() { this("#,##0.###"); }
    public DecimalFormat(String pattern) { applyPattern(pattern); }
    public DecimalFormat(String pattern, DecimalFormatSymbols s) { applyPattern(pattern); dec = s.getDecimalSeparator(); grp = s.getGroupingSeparator(); }
    static DecimalFormat localized(Locale l) { DecimalFormatSymbols s = new DecimalFormatSymbols(l); return new DecimalFormat("#,##0.###", s); }
    public void setDecimalFormatSymbols(DecimalFormatSymbols s) { dec = s.getDecimalSeparator(); grp = s.getGroupingSeparator(); }
    public void applyPattern(String p) {
        pattern = p;
        int semi = p.indexOf(';');
        if (semi >= 0) p = p.substring(0, semi);
        int start = 0, end = p.length();
        while (start < end && "#0,.".indexOf(p.charAt(start)) < 0) start++;
        int e = start;
        while (e < end && "#0,.".indexOf(p.charAt(e)) >= 0) e++;
        prefix = p.substring(0, start).replace("'", "");
        suffix = p.substring(e).replace("'", "");
        String num = p.substring(start, e);
        percent = suffix.contains("%") || prefix.contains("%");
        int dot = num.indexOf('.');
        String ip = dot < 0 ? num : num.substring(0, dot);
        String fp = dot < 0 ? "" : num.substring(dot + 1);
        int lc = ip.lastIndexOf(',');
        groupSize = lc < 0 ? 0 : ip.length() - lc - 1;
        grouping = groupSize > 0;
        minInt = 0;
        for (int i = 0; i < ip.length(); i++) if (ip.charAt(i) == '0') minInt++;
        minFrac = 0; maxFrac = 0;
        for (int i = 0; i < fp.length(); i++) { if (fp.charAt(i) == '0') minFrac++; maxFrac++; }
    }
    public String toPattern() { return pattern; }
    public String format(long l) { return fmt(new BigDecimal(l), l < 0); }
    public String format(double d) {
        if (Double.isNaN(d)) return "NaN";
        if (Double.isInfinite(d)) return (d < 0 ? "-" : "") + prefix + "∞" + suffix;
        return fmt(new BigDecimal(Math.abs(d)), d < 0 || (d == 0 && 1 / d < 0));
    }
    public String format(BigDecimal d) { return fmt(d.abs(), d.signum() < 0); }
    private String fmt(BigDecimal v, boolean neg) {
        v = v.abs();
        if (percent) v = v.multiply(BigDecimal.valueOf(100));
        v = v.setScale(maxFrac, rounding);
        String s = v.toPlainString();
        int dot = s.indexOf('.');
        String ip = dot < 0 ? s : s.substring(0, dot);
        String fp = dot < 0 ? "" : s.substring(dot + 1);
        while (fp.length() > minFrac && fp.endsWith("0")) fp = fp.substring(0, fp.length() - 1);
        if (ip.equals("0") && minInt == 0 && !fp.isEmpty()) ip = "";
        while (ip.length() < minInt) ip = "0" + ip;
        if (ip.length() > maxInt) ip = ip.substring(ip.length() - maxInt);
        if (grouping && groupSize > 0) {
            StringBuilder sb = new StringBuilder();
            for (int i = 0; i < ip.length(); i++) { if (i > 0 && (ip.length() - i) % groupSize == 0) sb.append(grp); sb.append(ip.charAt(i)); }
            ip = sb.toString();
        }
        String body = fp.isEmpty() ? ip : ip + dec + fp;
        boolean isZero = v.signum() == 0;
        return (neg && !isZero ? "-" : "") + prefix + body + suffix;
    }
    public Number parse(String s) throws ParseException {
        String t = s.trim();
        if (!prefix.isEmpty() && t.startsWith(prefix)) t = t.substring(prefix.length());
        StringBuilder sb = new StringBuilder();
        int i = 0;
        for (; i < t.length(); i++) {
            char c = t.charAt(i);
            if (c == grp) continue;
            if (c == dec) sb.append('.'); else if (Character.isDigit(c) || c == '-' || c == 'E') sb.append(c); else break;
        }
        if (sb.length() == 0) throw new ParseException("Unparseable number: \"" + s + "\"", 0);
        double d = Double.parseDouble(sb.toString());
        if (percent) d /= 100;
        if (d == Math.rint(d) && Math.abs(d) < 9e18) return Long.valueOf((long) d);
        return Double.valueOf(d);
    }
}
