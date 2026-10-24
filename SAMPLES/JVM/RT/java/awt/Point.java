package java.awt;
public class Point implements java.io.Serializable {
    public int x, y;
    public Point() { }
    public Point(Point p) { this(p.x, p.y); }
    public Point(int x, int y) { this.x = x; this.y = y; }
    public double getX() { return x; }
    public double getY() { return y; }
    public Point getLocation() { return new Point(x, y); }
    public void setLocation(int x, int y) { this.x = x; this.y = y; }
    public void setLocation(Point p) { setLocation(p.x, p.y); }
    public void move(int x, int y) { this.x = x; this.y = y; }
    public void translate(int dx, int dy) { this.x += dx; this.y += dy; }
    public boolean equals(Object obj) { return obj instanceof Point p && p.x == x && p.y == y; }
    public int hashCode() { return 31 * x + y; }
    public String toString() { return getClass().getName() + "[x=" + x + ",y=" + y + "]"; }
}
