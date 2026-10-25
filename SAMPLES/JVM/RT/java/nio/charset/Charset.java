package java.nio.charset;
public class Charset {
    private final String name;
    Charset(String name) { this.name = name; }
    public String name() { return name; }
    public String displayName() { return name; }
    public boolean isLatin1() { return name.equals("ISO-8859-1") || name.equals("US-ASCII"); }
    public String toString() { return name; }
    public static Charset forName(String n) { return new Charset(n.toUpperCase()); }
    public static Charset defaultCharset() { return StandardCharsets.UTF_8; }
}
