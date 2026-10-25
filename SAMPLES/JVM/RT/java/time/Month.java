package java.time;
import java.time.format.TextStyle;
public enum Month {
    JANUARY, FEBRUARY, MARCH, APRIL, MAY, JUNE, JULY, AUGUST, SEPTEMBER, OCTOBER, NOVEMBER, DECEMBER;
    private static final String[] N = { "January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December" };
    public int getValue() { return ordinal() + 1; }
    public static Month of(int m) { if (m < 1 || m > 12) throw new DateTimeException("Invalid value for MonthOfYear: " + m); return values()[m - 1]; }
    public Month plus(long months) { return values()[(int) ((ordinal() + (months % 12 + 12)) % 12)]; }
    public Month minus(long months) { return plus(-(months % 12)); }
    public int length(boolean leap) { switch (this) { case FEBRUARY: return leap ? 29 : 28; case APRIL: case JUNE: case SEPTEMBER: case NOVEMBER: return 30; default: return 31; } }
    public int maxLength() { return length(true); }
    public int minLength() { return length(false); }
    public String getDisplayName(TextStyle style, java.util.Locale l) {
        String n = N[ordinal()];
        if (l != null && l.getLanguage().equals("fr")) n = new String[] { "janvier", "février", "mars", "avril", "mai", "juin", "juillet", "août", "septembre", "octobre", "novembre", "décembre" }[ordinal()];
        return style == TextStyle.SHORT || style == TextStyle.SHORT_STANDALONE ? n.substring(0, 3) : (style == TextStyle.NARROW ? n.substring(0, 1) : n);
    }
}
