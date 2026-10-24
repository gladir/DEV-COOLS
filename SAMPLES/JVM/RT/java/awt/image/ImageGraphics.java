package java.awt.image;
import java.awt.*;
class ImageGraphics extends Graphics2D {
    private final BufferedImage img;
    private Color color = Color.BLACK;
    private Font font = new Font("Dialog", Font.PLAIN, 12);
    ImageGraphics(BufferedImage img) { this.img = img; }
    public Graphics create() { return new ImageGraphics(img); }
    public void translate(int x, int y) { }
    public Color getColor() { return color; }
    public void setColor(Color c) { color = c; }
    public Font getFont() { return font; }
    public void setFont(Font f) { font = f; }
    public Rectangle getClipBounds() { return new Rectangle(0, 0, img.getWidth(), img.getHeight()); }
    public void clipRect(int x, int y, int w, int h) { }
    public void setClip(int x, int y, int w, int h) { }
    public Shape getClip() { return null; }
    public void setClip(Shape s) { }
    public void drawLine(int x1, int y1, int x2, int y2) {
        int dx = Math.abs(x2 - x1), dy = Math.abs(y2 - y1), sx = x1 < x2 ? 1 : -1, sy = y1 < y2 ? 1 : -1, err = dx - dy;
        while (true) { img.setRGB(x1, y1, color.getRGB()); if (x1 == x2 && y1 == y2) break; int e2 = 2 * err; if (e2 > -dy) { err -= dy; x1 += sx; } if (e2 < dx) { err += dx; y1 += sy; } }
    }
    public void fillRect(int x, int y, int w, int h) { for (int j = 0; j < h; j++) for (int i = 0; i < w; i++) img.setRGB(x + i, y + j, color.getRGB()); }
    public void clearRect(int x, int y, int w, int h) { fillRect(x, y, w, h); }
    public void drawOval(int x, int y, int w, int h) { }
    public void fillOval(int x, int y, int w, int h) { }
    public void drawArc(int x, int y, int w, int h, int s, int a) { }
    public void fillArc(int x, int y, int w, int h, int s, int a) { }
    public void drawPolyline(int[] xs, int[] ys, int n) { for (int i = 0; i + 1 < n; i++) drawLine(xs[i], ys[i], xs[i + 1], ys[i + 1]); }
    public void drawPolygon(int[] xs, int[] ys, int n) { drawPolyline(xs, ys, n); if (n > 1) drawLine(xs[n - 1], ys[n - 1], xs[0], ys[0]); }
    public void fillPolygon(int[] xs, int[] ys, int n) { }
    public void drawString(String s, int x, int y) { }
    public boolean drawImage(Image i, int x, int y, ImageObserver o) { return true; }
    public void dispose() { }
}
