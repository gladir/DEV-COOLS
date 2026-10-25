package java.awt;
public class Dimension implements java.io.Serializable {
    public int width, height;
    public Dimension() { }
    public Dimension(Dimension d) { this(d.width, d.height); }
    public Dimension(int width, int height) { this.width = width; this.height = height; }
    public double getWidth() { return width; }
    public double getHeight() { return height; }
    public void setSize(int width, int height) { this.width = width; this.height = height; }
    public void setSize(Dimension d) { setSize(d.width, d.height); }
    public Dimension getSize() { return new Dimension(width, height); }
    public boolean equals(Object obj) { return obj instanceof Dimension d && d.width == width && d.height == height; }
    public int hashCode() { int sum = width + height; return sum * (sum + 1) / 2 + width; }
    public String toString() { return getClass().getName() + "[width=" + width + ",height=" + height + "]"; }
}
