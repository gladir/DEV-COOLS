package java.awt.geom;
import java.awt.*;
public abstract class Line2D implements Shape {
    public abstract double getX1();
    public abstract double getY1();
    public abstract double getX2();
    public abstract double getY2();
    public Rectangle getBounds() { int x = (int) Math.min(getX1(), getX2()), y = (int) Math.min(getY1(), getY2()); return new Rectangle(x, y, (int) Math.abs(getX2() - getX1()), (int) Math.abs(getY2() - getY1())); }
    public boolean contains(double x, double y) { return false; }
    public static class Double extends Line2D {
        public double x1, y1, x2, y2;
        public Double() { }
        public Double(double x1, double y1, double x2, double y2) { this.x1 = x1; this.y1 = y1; this.x2 = x2; this.y2 = y2; }
        public double getX1() { return x1; }
        public double getY1() { return y1; }
        public double getX2() { return x2; }
        public double getY2() { return y2; }
    }
    public static class Float extends Line2D {
        public float x1, y1, x2, y2;
        public Float() { }
        public Float(float x1, float y1, float x2, float y2) { this.x1 = x1; this.y1 = y1; this.x2 = x2; this.y2 = y2; }
        public double getX1() { return x1; }
        public double getY1() { return y1; }
        public double getX2() { return x2; }
        public double getY2() { return y2; }
    }
}
