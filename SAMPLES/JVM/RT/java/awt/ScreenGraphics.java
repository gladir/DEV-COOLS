package java.awt;
class ScreenGraphics extends Graphics2D {
    static int lx1 = -1, ly1 = -1, lx2 = -1, ly2 = -1;
    int tx, ty;
    int cx, cy, cw, ch;
    Color color = Color.BLACK;
    Font font = new Font("Dialog", Font.PLAIN, 12);
    ScreenGraphics(int tx, int ty, Rectangle clip) { this.tx = tx; this.ty = ty; cx = clip.x; cy = clip.y; cw = clip.width; ch = clip.height; }
    static void resetClip() { lx1 = ly1 = lx2 = ly2 = -1; }
    public Graphics create() { ScreenGraphics g = new ScreenGraphics(tx, ty, new Rectangle(cx, cy, cw, ch)); g.color = color; g.font = font; return g; }
    public void translate(int x, int y) { tx += x; ty += y; }
    public Color getColor() { return color; }
    public void setColor(Color c) { if (c != null) color = c; }
    public Font getFont() { return font; }
    public void setFont(Font f) { if (f != null) font = f; }
    public Rectangle getClipBounds() { return new Rectangle(cx - tx, cy - ty, cw, ch); }
    public void clipRect(int x, int y, int w, int h) {
        int x1 = Math.max(cx, x + tx), y1 = Math.max(cy, y + ty);
        int x2 = Math.min(cx + cw, x + tx + w), y2 = Math.min(cy + ch, y + ty + h);
        cx = x1; cy = y1; cw = Math.max(0, x2 - x1); ch = Math.max(0, y2 - y1);
    }
    public void setClip(int x, int y, int w, int h) { cx = x + tx; cy = y + ty; cw = w; ch = h; }
    public Shape getClip() { return getClipBounds(); }
    public void setClip(Shape s) { if (s == null) { cx = 0; cy = 0; cw = WM.screenW; ch = WM.screenH; } else { Rectangle r = s.getBounds(); setClip(r.x, r.y, r.width, r.height); } }
    private boolean apply() {
        if (cw <= 0 || ch <= 0) return false;
        int x1 = cx, y1 = cy, x2 = cx + cw - 1, y2 = cy + ch - 1;
        if (x1 != lx1 || y1 != ly1 || x2 != lx2 || y2 != ly2) { Gfx.setClip(x1, y1, x2, y2); lx1 = x1; ly1 = y1; lx2 = x2; ly2 = y2; }
        return true;
    }
    public void drawLine(int x1, int y1, int x2, int y2) { if (apply()) Gfx.drawLine(x1 + tx, y1 + ty, x2 + tx, y2 + ty, color.getRGB()); }
    public void fillRect(int x, int y, int w, int h) { if (apply()) Gfx.fillRect(x + tx, y + ty, w, h, color.getRGB()); }
    public void drawRect(int x, int y, int w, int h) { if (apply()) Gfx.drawRect(x + tx, y + ty, w, h, color.getRGB()); }
    public void clearRect(int x, int y, int w, int h) { Color c = color; color = new Color(238, 238, 238); fillRect(x, y, w, h); color = c; }
    public void drawOval(int x, int y, int w, int h) { if (apply()) Gfx.drawOval(x + tx, y + ty, w, h, color.getRGB()); }
    public void fillOval(int x, int y, int w, int h) { if (apply()) Gfx.fillOval(x + tx, y + ty, w, h, color.getRGB()); }
    public void drawArc(int x, int y, int w, int h, int s, int a) { if (apply()) Gfx.arc(x + tx, y + ty, w, h, s, a, color.getRGB(), 0); }
    public void fillArc(int x, int y, int w, int h, int s, int a) { if (apply()) Gfx.arc(x + tx, y + ty, w, h, s, a, color.getRGB(), 1); }
    public void drawRoundRect(int x, int y, int w, int h, int aw, int ah) {
        if (!apply()) return;
        int r = Math.min(Math.min(aw, ah) / 2, Math.min(w, h) / 2);
        int c = color.getRGB();
        Gfx.drawLine(x + tx + r, y + ty, x + tx + w - r, y + ty, c);
        Gfx.drawLine(x + tx + r, y + ty + h, x + tx + w - r, y + ty + h, c);
        Gfx.drawLine(x + tx, y + ty + r, x + tx, y + ty + h - r, c);
        Gfx.drawLine(x + tx + w, y + ty + r, x + tx + w, y + ty + h - r, c);
        Gfx.arc(x + tx, y + ty, 2 * r, 2 * r, 90, 90, c, 0);
        Gfx.arc(x + tx + w - 2 * r, y + ty, 2 * r, 2 * r, 0, 90, c, 0);
        Gfx.arc(x + tx, y + ty + h - 2 * r, 2 * r, 2 * r, 180, 90, c, 0);
        Gfx.arc(x + tx + w - 2 * r, y + ty + h - 2 * r, 2 * r, 2 * r, 270, 90, c, 0);
    }
    public void fillRoundRect(int x, int y, int w, int h, int aw, int ah) {
        if (!apply()) return;
        int r = Math.min(Math.min(aw, ah) / 2, Math.min(w, h) / 2);
        int c = color.getRGB();
        Gfx.fillRect(x + tx + r, y + ty, w - 2 * r + 1, h + 1, c);
        Gfx.fillRect(x + tx, y + ty + r, r, h - 2 * r + 1, c);
        Gfx.fillRect(x + tx + w - r + 1, y + ty + r, r, h - 2 * r + 1, c);
        Gfx.arc(x + tx, y + ty, 2 * r, 2 * r, 90, 90, c, 1);
        Gfx.arc(x + tx + w - 2 * r, y + ty, 2 * r, 2 * r, 0, 90, c, 1);
        Gfx.arc(x + tx, y + ty + h - 2 * r, 2 * r, 2 * r, 180, 90, c, 1);
        Gfx.arc(x + tx + w - 2 * r, y + ty + h - 2 * r, 2 * r, 2 * r, 270, 90, c, 1);
    }
    private void poly(int[] xs, int[] ys, int n, int fill) {
        if (!apply() || n < 2) return;
        int[] a = new int[n], b = new int[n];
        for (int i = 0; i < n; i++) { a[i] = xs[i] + tx; b[i] = ys[i] + ty; }
        Gfx.poly(a, b, n, color.getRGB(), fill);
    }
    public void drawPolyline(int[] xs, int[] ys, int n) { for (int i = 0; i + 1 < n; i++) drawLine(xs[i], ys[i], xs[i + 1], ys[i + 1]); }
    public void drawPolygon(int[] xs, int[] ys, int n) { poly(xs, ys, n, 0); }
    public void fillPolygon(int[] xs, int[] ys, int n) { poly(xs, ys, n, 1); }
    public void drawString(String s, int x, int y) {
        if (s == null || !apply()) return;
        int sc = font.scale();
        Gfx.drawText(x + tx, y + ty - 8 * sc + 1, s, color.getRGB(), sc);
    }
    public boolean drawImage(Image img, int x, int y, java.awt.image.ImageObserver o) {
        if (img instanceof java.awt.image.BufferedImage b && apply()) {
            for (int j = 0; j < b.getHeight(); j++) for (int i = 0; i < b.getWidth(); i++) {
                int p = b.getRGB(i, j);
                if ((p >>> 24) != 0) Gfx.fillRect(x + i + tx, y + j + ty, 1, 1, p);
            }
        }
        return true;
    }
    public void dispose() { }
}
