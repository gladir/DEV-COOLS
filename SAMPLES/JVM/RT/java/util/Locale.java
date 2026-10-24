package java.util;
public final class Locale {
    public static final Locale ENGLISH = new Locale("en", "");
    public static final Locale US = new Locale("en", "US");
    public static final Locale UK = new Locale("en", "GB");
    public static final Locale FRENCH = new Locale("fr", "");
    public static final Locale FRANCE = new Locale("fr", "FR");
    public static final Locale CANADA_FRENCH = new Locale("fr", "CA");
    public static final Locale GERMAN = new Locale("de", "");
    public static final Locale ROOT = new Locale("", "");
    private final String lang, country;
    public Locale(String lang) { this(lang, ""); }
    public Locale(String lang, String country) { this.lang = lang; this.country = country; }
    public static Locale getDefault() { return US; }
    public static Locale forLanguageTag(String t) { return new Locale(t); }
    public static Locale of(String l) { return new Locale(l); }
    public static Locale of(String l, String c) { return new Locale(l, c); }
    public String getLanguage() { return lang; }
    public String getCountry() { return country; }
    public String toString() { return country.isEmpty() ? lang : lang + "_" + country; }
}
