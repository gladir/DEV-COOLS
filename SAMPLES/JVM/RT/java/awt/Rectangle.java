package java.awt;
public class Rectangle implements Shape, java.io.Serializable {
    public int x, y, width, height;
    public Rectangle() { }
    public Rectangle(Rectangle r) { this(r.x, r.y, r.width, r.height); }
    public Rectangle(int x, int y, int width, int height) { this.x = x; this.y = y; this.width = width; this.height = height; }
    public Rectangle(int width, int height) { this(0, 0, width, height); }
    public Rectangle(Point p, Dimension d) { this(p.x, p.y, d.width, d.height); }
    public double getX() { return x; }
    public double getY() { return y; }
    public double getWidth() { return width; }
    public double getHeight() { return height; }
    public Rectangle getBounds() { return new Rectangle(x, y, width, height); }
    public Point getLocation() { return new Point(x, y); }
    public Dimension getSize() { return new Dimension(width, height); }
    public void setBounds(int x, int y, int width, int height) { this.x = x; this.y = y; this.width = width; this.height = height; }
    public void setBounds(Rectangle r) { setBounds(r.x, r.y, r.width, r.height); }
    public void setRect(double x, double y, double w, double h) { setBounds((int) x, (int) y, (int) w, (int) h); }
    public void setLocation(int x, int y) { this.x = x; this.y = y; }
    public void setSize(int w, int h) { this.width = w; this.height = h; }
    public void translate(int dx, int dy) { x += dx; y += dy; }
    public boolean isEmpty() { return (width <= 0) || (height <= 0); }
    public boolean contains(int X, int Y) { return X >= x && Y >= y && X < x + width && Y < y + height; }
    public boolean contains(double X, double Y) { return X >= x && Y >= y && X < x + width && Y < y + height; }
    public boolean contains(Point p) { return contains(p.x, p.y); }
    public boolean contains(Rectangle r) { return r.x >= x && r.y >= y && r.x + r.width <= x + width && r.y + r.height <= y + height; }
    public boolean intersects(Rectangle r) { return !intersection(r).isEmpty(); }
    public Rectangle intersection(Rectangle r) {
        int x1 = Math.max(x, r.x), y1 = Math.max(y, r.y);
        int x2 = Math.min(x + width, r.x + r.width), y2 = Math.min(y + height, r.y + r.height);
        return new Rectangle(x1, y1, Math.max(0, x2 - x1), Math.max(0, y2 - y1));
    }
    public Rectangle union(Rectangle r) {
        int x1 = Math.min(x, r.x), y1 = Math.min(y, r.y);
        int x2 = Math.max(x + width, r.x + r.width), y2 = Math.max(y + height, r.y + r.height);
        return new Rectangle(x1, y1, x2 - x1, y2 - y1);
    }
    public void grow(int h, int v) { x -= h; y -= v; width += h * 2; height += v * 2; }
    public boolean equals(Object obj) { return obj instanceof Rectangle r && r.x == x && r.y == y && r.width == width && r.height == height; }
    public int hashCode() { return x * 31 * 31 * 31 + y * 31 * 31 + width * 31 + height; }
    public String toString() { return getClass().getName() + "[x=" + x + ",y=" + y + ",width=" + width + ",height=" + height + "]"; }
}
