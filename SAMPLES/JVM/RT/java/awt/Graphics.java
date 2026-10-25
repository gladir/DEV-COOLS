package java.awt;
public abstract class Graphics {
    protected Graphics() { }
    public abstract Graphics create();
    public Graphics create(int x, int y, int width, int height) { Graphics g = create(); g.translate(x, y); g.clipRect(0, 0, width, height); return g; }
    public abstract void translate(int x, int y);
    public abstract Color getColor();
    public abstract void setColor(Color c);
    public abstract Font getFont();
    public abstract void setFont(Font font);
    public FontMetrics getFontMetrics() { return getFontMetrics(getFont()); }
    public FontMetrics getFontMetrics(Font f) { return new FontMetrics(f); }
    public abstract Rectangle getClipBounds();
    public abstract void clipRect(int x, int y, int width, int height);
    public abstract void setClip(int x, int y, int width, int height);
    public abstract Shape getClip();
    public abstract void setClip(Shape clip);
    public void setPaintMode() { }
    public void setXORMode(Color c1) { }
    public abstract void drawLine(int x1, int y1, int x2, int y2);
    public abstract void fillRect(int x, int y, int width, int height);
    public void drawRect(int x, int y, int width, int height) {
        if ((width < 0) || (height < 0)) return;
        if (height == 0 || width == 0) drawLine(x, y, x + width, y + height);
        else {
            drawLine(x, y, x + width - 1, y);
            drawLine(x + width, y, x + width, y + height - 1);
            drawLine(x + width, y + height, x + 1, y + height);
            drawLine(x, y + height, x, y + 1);
        }
    }
    public abstract void clearRect(int x, int y, int width, int height);
    public void drawRoundRect(int x, int y, int width, int height, int arcWidth, int arcHeight) { drawRect(x, y, width, height); }
    public void fillRoundRect(int x, int y, int width, int height, int arcWidth, int arcHeight) { fillRect(x, y, width, height); }
    public void draw3DRect(int x, int y, int width, int height, boolean raised) {
        Color c = getColor();
        Color brighter = c.brighter();
        Color darker = c.darker();
        setColor(raised ? brighter : darker);
        drawLine(x, y, x, y + height);
        drawLine(x + 1, y, x + width - 1, y);
        setColor(raised ? darker : brighter);
        drawLine(x + 1, y + height, x + width, y + height);
        drawLine(x + width, y, x + width, y + height - 1);
        setColor(c);
    }
    public void fill3DRect(int x, int y, int width, int height, boolean raised) {
        Color c = getColor();
        Color brighter = c.brighter();
        Color darker = c.darker();
        if (!raised) setColor(darker);
        fillRect(x + 1, y + 1, width - 2, height - 2);
        setColor(raised ? brighter : darker);
        drawLine(x, y, x, y + height - 1);
        drawLine(x + 1, y, x + width - 2, y);
        setColor(raised ? darker : brighter);
        drawLine(x + 1, y + height - 1, x + width - 1, y + height - 1);
        drawLine(x + width - 1, y, x + width - 1, y + height - 2);
        setColor(c);
    }
    public abstract void drawOval(int x, int y, int width, int height);
    public abstract void fillOval(int x, int y, int width, int height);
    public abstract void drawArc(int x, int y, int width, int height, int startAngle, int arcAngle);
    public abstract void fillArc(int x, int y, int width, int height, int startAngle, int arcAngle);
    public abstract void drawPolyline(int[] xPoints, int[] yPoints, int nPoints);
    public abstract void drawPolygon(int[] xPoints, int[] yPoints, int nPoints);
    public void drawPolygon(Polygon p) { drawPolygon(p.xpoints, p.ypoints, p.npoints); }
    public abstract void fillPolygon(int[] xPoints, int[] yPoints, int nPoints);
    public void fillPolygon(Polygon p) { fillPolygon(p.xpoints, p.ypoints, p.npoints); }
    public abstract void drawString(String str, int x, int y);
    public void drawChars(char[] data, int offset, int length, int x, int y) { drawString(new String(data, offset, length), x, y); }
    public abstract boolean drawImage(Image img, int x, int y, java.awt.image.ImageObserver observer);
    public abstract void dispose();
    public void finalize() { dispose(); }
    public String toString() { return getClass().getName() + "[font=" + getFont() + ",color=" + getColor() + "]"; }
}
