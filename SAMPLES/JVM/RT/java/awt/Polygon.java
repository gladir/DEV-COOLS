package java.awt;
public class Polygon implements Shape {
    public int npoints;
    public int[] xpoints = new int[4];
    public int[] ypoints = new int[4];
    public Polygon() { }
    public Polygon(int[] xpoints, int[] ypoints, int npoints) {
        this.npoints = npoints;
        this.xpoints = java.util.Arrays.copyOf(xpoints, npoints);
        this.ypoints = java.util.Arrays.copyOf(ypoints, npoints);
    }
    public void addPoint(int x, int y) {
        if (npoints >= xpoints.length) { xpoints = java.util.Arrays.copyOf(xpoints, npoints * 2); ypoints = java.util.Arrays.copyOf(ypoints, npoints * 2); }
        xpoints[npoints] = x; ypoints[npoints] = y; npoints++;
    }
    public Rectangle getBounds() {
        if (npoints == 0) return new Rectangle();
        int x1 = xpoints[0], y1 = ypoints[0], x2 = x1, y2 = y1;
        for (int i = 1; i < npoints; i++) { x1 = Math.min(x1, xpoints[i]); x2 = Math.max(x2, xpoints[i]); y1 = Math.min(y1, ypoints[i]); y2 = Math.max(y2, ypoints[i]); }
        return new Rectangle(x1, y1, x2 - x1, y2 - y1);
    }
    public boolean contains(double x, double y) {
        boolean in = false;
        for (int i = 0, j = npoints - 1; i < npoints; j = i++) {
            if (((ypoints[i] > y) != (ypoints[j] > y)) && (x < (double) (xpoints[j] - xpoints[i]) * (y - ypoints[i]) / (ypoints[j] - ypoints[i]) + xpoints[i])) in = !in;
        }
        return in;
    }
    public boolean contains(int x, int y) { return contains((double) x, (double) y); }
    public void translate(int dx, int dy) { for (int i = 0; i < npoints; i++) { xpoints[i] += dx; ypoints[i] += dy; } }
}
