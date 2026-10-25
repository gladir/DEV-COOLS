package java.awt;
import java.awt.geom.*;
public abstract class Graphics2D extends Graphics {
    protected Graphics2D() { }
    public void setRenderingHint(RenderingHints.Key hintKey, Object hintValue) { }
    public void setRenderingHints(java.util.Map<?, ?> hints) { }
    public void setStroke(Stroke s) { }
    public Stroke getStroke() { return new BasicStroke(); }
    public void setPaint(Paint p) { if (p instanceof Color) setColor((Color) p); }
    public void setBackground(Color c) { }
    public void draw(Shape s) {
        if (s instanceof Line2D l) drawLine((int) l.getX1(), (int) l.getY1(), (int) l.getX2(), (int) l.getY2());
        else if (s instanceof Ellipse2D e) drawOval((int) e.getX(), (int) e.getY(), (int) e.getWidth(), (int) e.getHeight());
        else if (s instanceof Rectangle2D r) drawRect((int) r.getX(), (int) r.getY(), (int) r.getWidth(), (int) r.getHeight());
        else if (s instanceof Polygon p) drawPolygon(p);
        else { Rectangle r = s.getBounds(); drawRect(r.x, r.y, r.width, r.height); }
    }
    public void fill(Shape s) {
        if (s instanceof Ellipse2D e) fillOval((int) e.getX(), (int) e.getY(), (int) e.getWidth(), (int) e.getHeight());
        else if (s instanceof Rectangle2D r) fillRect((int) r.getX(), (int) r.getY(), (int) r.getWidth(), (int) r.getHeight());
        else if (s instanceof Polygon p) fillPolygon(p);
        else { Rectangle r = s.getBounds(); fillRect(r.x, r.y, r.width, r.height); }
    }
    public void rotate(double theta) { }
    public void scale(double sx, double sy) { }
    public void translate(double tx, double ty) { translate((int) tx, (int) ty); }
    public void drawString(String s, float x, float y) { drawString(s, (int) x, (int) y); }
}
