package java.awt;
public class Font implements java.io.Serializable {
    public static final int PLAIN = 0;
    public static final int BOLD = 1;
    public static final int ITALIC = 2;
    public static final String DIALOG = "Dialog";
    public static final String DIALOG_INPUT = "DialogInput";
    public static final String SANS_SERIF = "SansSerif";
    public static final String SERIF = "Serif";
    public static final String MONOSPACED = "Monospaced";
    protected String name;
    protected int style;
    protected int size;
    public Font(String name, int style, int size) { this.name = (name != null) ? name : "Default"; this.style = (style & ~0x03) == 0 ? style : 0; this.size = size; }
    public String getName() { return name; }
    public String getFamily() { return name; }
    public String getFontName() { return name; }
    public int getStyle() { return style; }
    public int getSize() { return size; }
    public float getSize2D() { return size; }
    public boolean isPlain() { return style == 0; }
    public boolean isBold() { return (style & BOLD) != 0; }
    public boolean isItalic() { return (style & ITALIC) != 0; }
    public Font deriveFont(int style) { return new Font(name, style, size); }
    public Font deriveFont(float size) { return new Font(name, style, (int) size); }
    public Font deriveFont(int style, float size) { return new Font(name, style, (int) size); }
    public static Font decode(String str) { return new Font(str, PLAIN, 12); }
    int scale() { return size < 22 ? 1 : (size < 34 ? 2 : 3); }
    public boolean equals(Object obj) { return obj instanceof Font f && f.name.equals(name) && f.style == style && f.size == size; }
    public int hashCode() { return name.hashCode() ^ style ^ size; }
    public String toString() { return getClass().getName() + "[family=" + name + ",name=" + name + ",style=" + (style == 0 ? "plain" : style == 1 ? "bold" : style == 2 ? "italic" : "bolditalic") + ",size=" + size + "]"; }
}
