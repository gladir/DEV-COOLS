package java.util;
import java.io.*;
public final class Locale implements Cloneable, Serializable {
    static final long serialVersionUID = 9149081749638150636L;
    private static final HashMap<String, Locale> cache = new HashMap<>();
    private transient String language, script, country, variant;
    private transient int hashCodeValue;
    private static final ObjectStreamField[] serialPersistentFields = {
        new ObjectStreamField("language", String.class),
        new ObjectStreamField("country", String.class),
        new ObjectStreamField("variant", String.class),
        new ObjectStreamField("hashcode", int.class),
        new ObjectStreamField("script", String.class),
        new ObjectStreamField("extensions", String.class),
    };
    public static final Locale ENGLISH = createConstant("en", "");
    public static final Locale FRENCH = createConstant("fr", "");
    public static final Locale GERMAN = createConstant("de", "");
    public static final Locale ITALIAN = createConstant("it", "");
    public static final Locale JAPANESE = createConstant("ja", "");
    public static final Locale KOREAN = createConstant("ko", "");
    public static final Locale CHINESE = createConstant("zh", "");
    public static final Locale SIMPLIFIED_CHINESE = createConstant("zh", "CN");
    public static final Locale TRADITIONAL_CHINESE = createConstant("zh", "TW");
    public static final Locale FRANCE = createConstant("fr", "FR");
    public static final Locale GERMANY = createConstant("de", "DE");
    public static final Locale ITALY = createConstant("it", "IT");
    public static final Locale JAPAN = createConstant("ja", "JP");
    public static final Locale KOREA = createConstant("ko", "KR");
    public static final Locale UK = createConstant("en", "GB");
    public static final Locale US = createConstant("en", "US");
    public static final Locale CANADA = createConstant("en", "CA");
    public static final Locale CANADA_FRENCH = createConstant("fr", "CA");
    public static final Locale ROOT = createConstant("", "");
    public static final Locale CHINA = SIMPLIFIED_CHINESE;
    public static final Locale PRC = SIMPLIFIED_CHINESE;
    public static final Locale TAIWAN = TRADITIONAL_CHINESE;
    private static Locale defaultLocale = US;
    private static Locale defaultDisplay = US;
    private static Locale defaultFormat = US;
    public enum Category { DISPLAY, FORMAT }
    private Locale(String language, String script, String country, String variant) {
        this.language = language; this.script = script; this.country = country; this.variant = variant;
    }
    private static Locale createConstant(String lang, String country) {
        Locale l = new Locale(lang, "", country, "");
        cache.put(key(lang, "", country, ""), l);
        return l;
    }
    private static String key(String l, String s, String c, String v) { return l + "\u0000" + s + "\u0000" + c + "\u0000" + v; }
    private static String convertOldISOCodes(String language) {
        if (language.equals("iw")) return "he";
        if (language.equals("ji")) return "yi";
        if (language.equals("in")) return "id";
        return language;
    }
    private static Locale getInstance(String language, String script, String country, String variant) {
        String k = key(language, script, country, variant);
        synchronized (cache) {
            Locale l = cache.get(k);
            if (l == null) { l = new Locale(language, script, country, variant); cache.put(k, l); }
            return l;
        }
    }
    public Locale(String language, String country, String variant) {
        if (language == null || country == null || variant == null) throw new NullPointerException();
        this.language = convertOldISOCodes(language.toLowerCase());
        this.script = "";
        this.country = country.toUpperCase();
        this.variant = variant;
    }
    public Locale(String language, String country) { this(language, country, ""); }
    public Locale(String language) { this(language, "", ""); }
    public static Locale of(String language) { return getInstance(convertOldISOCodes(language.toLowerCase()), "", "", ""); }
    public static Locale of(String language, String country) { return getInstance(convertOldISOCodes(language.toLowerCase()), "", country.toUpperCase(), ""); }
    public static Locale of(String language, String country, String variant) { return getInstance(convertOldISOCodes(language.toLowerCase()), "", country.toUpperCase(), variant); }
    public static Locale getDefault() { return defaultLocale; }
    public static Locale getDefault(Locale.Category category) { return category == Category.DISPLAY ? defaultDisplay : defaultFormat; }
    public static synchronized void setDefault(Locale newLocale) {
        if (newLocale == null) throw new NullPointerException("Can't set default locale to NULL");
        defaultLocale = newLocale; defaultDisplay = newLocale; defaultFormat = newLocale;
    }
    public static synchronized void setDefault(Locale.Category category, Locale newLocale) {
        if (newLocale == null) throw new NullPointerException("Can't set default locale to NULL");
        if (category == Category.DISPLAY) defaultDisplay = newLocale; else defaultFormat = newLocale;
    }
    public static Locale[] getAvailableLocales() { return new Locale[]{ROOT, ENGLISH, US, UK, CANADA, FRENCH, FRANCE, CANADA_FRENCH, GERMAN, GERMANY, ITALIAN, ITALY, JAPANESE, JAPAN, KOREAN, KOREA, CHINESE, CHINA, TAIWAN}; }
    public static String[] getISOCountries() { return new String[]{"AU", "BR", "CA", "CH", "CN", "DE", "ES", "FR", "GB", "IN", "IT", "JP", "KR", "MX", "RU", "TW", "US"}; }
    public static String[] getISOLanguages() { return new String[]{"de", "en", "es", "fr", "it", "ja", "ko", "pt", "ru", "zh"}; }
    public String getLanguage() { return language; }
    public String getScript() { return script; }
    public String getCountry() { return country; }
    public String getVariant() { return variant; }
    public boolean hasExtensions() { return false; }
    public Locale stripExtensions() { return this; }
    public String getExtension(char key) { return null; }
    public Set<Character> getExtensionKeys() { return Collections.emptySet(); }
    public Object clone() { return this; }
    public int hashCode() {
        int hc = hashCodeValue;
        if (hc == 0) {
            hc = language.hashCode();
            hc = 31 * hc + script.hashCode();
            hc = 31 * hc + country.hashCode();
            hc = 31 * hc + variant.hashCode();
            hashCodeValue = hc;
        }
        return hc;
    }
    public boolean equals(Object obj) {
        if (this == obj) return true;
        if (!(obj instanceof Locale)) return false;
        Locale o = (Locale) obj;
        return language.equals(o.language) && script.equals(o.script) && country.equals(o.country) && variant.equals(o.variant);
    }
    public final String toString() {
        boolean l = language.length() != 0;
        boolean s = script.length() != 0;
        boolean r = country.length() != 0;
        boolean v = variant.length() != 0;
        StringBuilder result = new StringBuilder(language);
        if (r || (l && (v || s))) result.append('_').append(country);
        if (v && (l || r)) result.append('_').append(variant);
        if (s && (l || r)) result.append("_#").append(script);
        return result.toString();
    }
    public String toLanguageTag() {
        StringBuilder sb = new StringBuilder();
        sb.append(language.isEmpty() ? "und" : language);
        if (!script.isEmpty()) sb.append('-').append(script);
        if (!country.isEmpty()) sb.append('-').append(country);
        if (!variant.isEmpty()) sb.append('-').append(variant);
        return sb.toString();
    }
    public static Locale forLanguageTag(String languageTag) {
        String[] p = languageTag.split("[-_]");
        String lang = "", scr = "", ctry = "", var = "";
        int i = 0;
        if (p.length > 0 && !p[0].equals("und")) lang = convertOldISOCodes(p[0].toLowerCase());
        i = 1;
        if (i < p.length && p[i].length() == 4 && Character.isLetter(p[i].charAt(0))) { scr = Character.toUpperCase(p[i].charAt(0)) + p[i].substring(1).toLowerCase(); i++; }
        if (i < p.length && (p[i].length() == 2 || (p[i].length() == 3 && Character.isDigit(p[i].charAt(0))))) { ctry = p[i].toUpperCase(); i++; }
        if (i < p.length) var = p[i];
        return getInstance(lang, scr, ctry, var);
    }
    private static final String[][] LANGS = {{"en", "English"}, {"fr", "French"}, {"de", "German"}, {"es", "Spanish"}, {"it", "Italian"}, {"pt", "Portuguese"}, {"ja", "Japanese"}, {"ko", "Korean"}, {"zh", "Chinese"}, {"ru", "Russian"}, {"nl", "Dutch"}, {"sv", "Swedish"}, {"pl", "Polish"}, {"ar", "Arabic"}, {"hi", "Hindi"}};
    private static final String[][] CTRY = {{"US", "United States"}, {"GB", "United Kingdom"}, {"FR", "France"}, {"DE", "Germany"}, {"CA", "Canada"}, {"IT", "Italy"}, {"JP", "Japan"}, {"KR", "South Korea"}, {"CN", "China"}, {"TW", "Taiwan"}, {"ES", "Spain"}, {"BR", "Brazil"}, {"RU", "Russia"}, {"IN", "India"}, {"MX", "Mexico"}, {"AU", "Australia"}, {"CH", "Switzerland"}};
    private static String lookup(String[][] t, String k) {
        for (String[] e : t) if (e[0].equals(k)) return e[1];
        return k;
    }
    public String getDisplayLanguage() { return language.isEmpty() ? "" : lookup(LANGS, language); }
    public String getDisplayLanguage(Locale inLocale) { return getDisplayLanguage(); }
    public String getDisplayCountry() { return country.isEmpty() ? "" : lookup(CTRY, country); }
    public String getDisplayCountry(Locale inLocale) { return getDisplayCountry(); }
    public String getDisplayScript() { return script; }
    public String getDisplayVariant() { return variant; }
    public String getDisplayName() { return getDisplayName(null); }
    public String getDisplayName(Locale inLocale) {
        String l = getDisplayLanguage(), c = getDisplayCountry();
        if (l.isEmpty()) return c;
        if (c.isEmpty() && variant.isEmpty()) return l;
        StringBuilder sb = new StringBuilder(l).append(" (");
        if (!c.isEmpty()) sb.append(c);
        if (!variant.isEmpty()) { if (!c.isEmpty()) sb.append(", "); sb.append(variant); }
        return sb.append(')').toString();
    }
    public String getISO3Language() { return language; }
    public String getISO3Country() { return country; }
    private void writeObject(ObjectOutputStream out) throws IOException {
        ObjectOutputStream.PutField fields = out.putFields();
        fields.put("language", language);
        fields.put("script", script);
        fields.put("country", country);
        fields.put("variant", variant);
        fields.put("extensions", "");
        fields.put("hashcode", -1);
        out.writeFields();
    }
    private void readObject(ObjectInputStream in) throws IOException, ClassNotFoundException {
        ObjectInputStream.GetField fields = in.readFields();
        language = (String) fields.get("language", "");
        script = (String) fields.get("script", "");
        country = (String) fields.get("country", "");
        variant = (String) fields.get("variant", "");
        hashCodeValue = 0;
    }
    private Object readResolve() throws ObjectStreamException { return getInstance(language, script, country, variant); }
}
