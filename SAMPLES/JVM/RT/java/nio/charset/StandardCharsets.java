package java.nio.charset;
public final class StandardCharsets {
    private StandardCharsets() {}
    public static final Charset UTF_8 = new Charset("UTF-8");
    public static final Charset ISO_8859_1 = new Charset("ISO-8859-1");
    public static final Charset US_ASCII = new Charset("US-ASCII");
    public static final Charset UTF_16 = new Charset("UTF-16");
}
