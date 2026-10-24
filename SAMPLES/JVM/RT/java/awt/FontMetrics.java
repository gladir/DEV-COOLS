package java.awt;
public class FontMetrics implements java.io.Serializable {
    protected Font font;
    public FontMetrics(Font font) { this.font = font; }
    public static FontMetrics of(Font f) { return new FontMetrics(f); }
    public Font getFont() { return font; }
    public int getAscent() { return 8 * font.scale(); }
    public int getDescent() { return 3; }
    public int getLeading() { return 0; }
    public int getHeight() { return getAscent() + getDescent() + getLeading(); }
    public int getMaxAscent() { return getAscent(); }
    public int getMaxDescent() { return getDescent(); }
    public int getMaxAdvance() { return 8 * font.scale(); }
    public int charWidth(char ch) { return 8 * font.scale(); }
    public int charWidth(int ch) { return 8 * font.scale(); }
    public int stringWidth(String str) { return str.length() * 8 * font.scale(); }
    public int charsWidth(char[] data, int off, int len) { return len * 8 * font.scale(); }
    public java.awt.geom.Rectangle2D getStringBounds(String str, Graphics g) { return new java.awt.geom.Rectangle2D.Double(0, -getAscent(), stringWidth(str), getHeight()); }
}
