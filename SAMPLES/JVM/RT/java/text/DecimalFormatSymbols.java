package java.text;
import java.util.Locale;
public class DecimalFormatSymbols {
    private char dec = '.', grp = ',';
    public DecimalFormatSymbols() { }
    public DecimalFormatSymbols(Locale l) { if (l != null && (l.getLanguage().equals("fr") || l.getLanguage().equals("de"))) { dec = ','; grp = l.getLanguage().equals("fr") ? ' ' : '.'; } }
    public static DecimalFormatSymbols getInstance() { return new DecimalFormatSymbols(); }
    public static DecimalFormatSymbols getInstance(Locale l) { return new DecimalFormatSymbols(l); }
    public char getDecimalSeparator() { return dec; }
    public char getGroupingSeparator() { return grp; }
    public void setDecimalSeparator(char c) { dec = c; }
    public void setGroupingSeparator(char c) { grp = c; }
}
