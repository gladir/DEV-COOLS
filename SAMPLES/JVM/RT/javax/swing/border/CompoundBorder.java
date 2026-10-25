package javax.swing.border;
import java.awt.*;
public class CompoundBorder extends AbstractBorder {
    protected Border outsideBorder, insideBorder;
    public CompoundBorder(Border outside, Border inside) { outsideBorder = outside; insideBorder = inside; }
    public void paintBorder(Component c, Graphics g, int x, int y, int w, int h) {
        Insets oi = outsideBorder.getBorderInsets(c);
        outsideBorder.paintBorder(c, g, x, y, w, h);
        insideBorder.paintBorder(c, g, x + oi.left, y + oi.top, w - oi.left - oi.right, h - oi.top - oi.bottom);
    }
    public Insets getBorderInsets(Component c) {
        Insets o = outsideBorder.getBorderInsets(c), i = insideBorder.getBorderInsets(c);
        return new Insets(o.top + i.top, o.left + i.left, o.bottom + i.bottom, o.right + i.right);
    }
}
