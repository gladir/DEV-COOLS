package java.awt.geom;
public abstract class Point2D {
    public abstract double getX();
    public abstract double getY();
    public static class Double extends Point2D {
        public double x, y;
        public Double() { }
        public Double(double x, double y) { this.x = x; this.y = y; }
        public double getX() { return x; }
        public double getY() { return y; }
    }
    public static class Float extends Point2D {
        public float x, y;
        public Float() { }
        public Float(float x, float y) { this.x = x; this.y = y; }
        public double getX() { return x; }
        public double getY() { return y; }
    }
}
