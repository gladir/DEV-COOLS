package java.text;
import java.util.Locale;
public abstract class NumberFormat extends Format {
    private static final long serialVersionUID = -2308460125733713944L;
    protected boolean grouping = true;
    protected int maxFrac = 3, minFrac = 0, minInt = 1, maxInt = Integer.MAX_VALUE;
    protected java.math.RoundingMode rounding = java.math.RoundingMode.HALF_EVEN;
    public abstract String format(double d);
    public abstract String format(long l);
    String formatObject(Object o) { return o instanceof Long || o instanceof Integer || o instanceof Short || o instanceof Byte ? format(((Number) o).longValue()) : format(((Number) o).doubleValue()); }
    public abstract Number parse(String s) throws ParseException;
    public static NumberFormat getInstance() { return new DecimalFormat("#,##0.###"); }
    public static NumberFormat getInstance(Locale l) { return l != null && (l.getLanguage().equals("fr") || l.getLanguage().equals("de")) ? DecimalFormat.localized(l) : getInstance(); }
    public static NumberFormat getNumberInstance() { return getInstance(); }
    public static NumberFormat getNumberInstance(Locale l) { return getInstance(l); }
    public static NumberFormat getIntegerInstance() { DecimalFormat d = new DecimalFormat("#,##0"); d.setRoundingMode(java.math.RoundingMode.HALF_EVEN); return d; }
    public static NumberFormat getCurrencyInstance() { return new DecimalFormat("$#,##0.00"); }
    public static NumberFormat getCurrencyInstance(Locale l) {
        if (l != null && l.getLanguage().equals("fr")) { DecimalFormat d = DecimalFormat.localized(l); d.applyPattern("#,##0.00 €"); return d; }
        return new DecimalFormat("$#,##0.00");
    }
    public static NumberFormat getPercentInstance() { return new DecimalFormat("#,##0%"); }
    public void setMaximumFractionDigits(int n) { maxFrac = n; if (minFrac > n) minFrac = n; }
    public void setMinimumFractionDigits(int n) { minFrac = n; if (maxFrac < n) maxFrac = n; }
    public void setMinimumIntegerDigits(int n) { minInt = n; }
    public void setMaximumIntegerDigits(int n) { maxInt = n; }
    public int getMaximumFractionDigits() { return maxFrac; }
    public int getMinimumFractionDigits() { return minFrac; }
    public void setGroupingUsed(boolean b) { grouping = b; }
    public void setRoundingMode(java.math.RoundingMode m) { rounding = m; }
    public void setParseIntegerOnly(boolean b) { }
}
