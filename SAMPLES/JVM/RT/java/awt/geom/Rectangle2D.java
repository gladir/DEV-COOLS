package java.awt.geom;
import java.awt.*;
public abstract class Rectangle2D implements Shape {
    public abstract double getX();
    public abstract double getY();
    public abstract double getWidth();
    public abstract double getHeight();
    public Rectangle getBounds() { return new Rectangle((int) getX(), (int) getY(), (int) Math.ceil(getWidth()), (int) Math.ceil(getHeight())); }
    public boolean contains(double x, double y) { return x >= getX() && y >= getY() && x < getX() + getWidth() && y < getY() + getHeight(); }
    public double getMaxX() { return getX() + getWidth(); }
    public double getMaxY() { return getY() + getHeight(); }
    public double getCenterX() { return getX() + getWidth() / 2; }
    public double getCenterY() { return getY() + getHeight() / 2; }
    public static class Double extends Rectangle2D {
        public double x, y, width, height;
        public Double() { }
        public Double(double x, double y, double w, double h) { this.x = x; this.y = y; this.width = w; this.height = h; }
        public double getX() { return x; }
        public double getY() { return y; }
        public double getWidth() { return width; }
        public double getHeight() { return height; }
    }
    public static class Float extends Rectangle2D {
        public float x, y, width, height;
        public Float() { }
        public Float(float x, float y, float w, float h) { this.x = x; this.y = y; this.width = w; this.height = h; }
        public double getX() { return x; }
        public double getY() { return y; }
        public double getWidth() { return width; }
        public double getHeight() { return height; }
    }
}
