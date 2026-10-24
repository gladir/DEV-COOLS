package java.time;
import java.time.format.TextStyle;
public enum DayOfWeek {
    MONDAY, TUESDAY, WEDNESDAY, THURSDAY, FRIDAY, SATURDAY, SUNDAY;
    private static final String[] N = { "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday" };
    public int getValue() { return ordinal() + 1; }
    public static DayOfWeek of(int d) { if (d < 1 || d > 7) throw new DateTimeException("Invalid value for DayOfWeek: " + d); return values()[d - 1]; }
    public DayOfWeek plus(long days) { return values()[(int) ((ordinal() + (days % 7 + 7)) % 7)]; }
    public DayOfWeek minus(long days) { return plus(-(days % 7)); }
    public String getDisplayName(TextStyle style, java.util.Locale l) {
        String n = N[ordinal()];
        if (l != null && l.getLanguage().equals("fr")) n = new String[] { "lundi", "mardi", "mercredi", "jeudi", "vendredi", "samedi", "dimanche" }[ordinal()];
        return style == TextStyle.SHORT || style == TextStyle.SHORT_STANDALONE ? n.substring(0, 3) : (style == TextStyle.NARROW ? n.substring(0, 1) : n);
    }
}
