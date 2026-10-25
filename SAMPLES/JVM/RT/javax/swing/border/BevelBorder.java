package javax.swing.border;
import java.awt.*;
public class BevelBorder extends AbstractBorder {
    public static final int RAISED = 0, LOWERED = 1;
    protected int bevelType;
    public BevelBorder(int bevelType) { this.bevelType = bevelType; }
    public void paintBorder(Component c, Graphics g, int x, int y, int w, int h) {
        Color old = g.getColor();
        g.setColor(bevelType == RAISED ? Color.WHITE : new Color(122, 138, 153));
        g.drawLine(x, y, x + w - 2, y); g.drawLine(x, y, x, y + h - 2);
        g.setColor(bevelType == RAISED ? new Color(122, 138, 153) : Color.WHITE);
        g.drawLine(x, y + h - 1, x + w - 1, y + h - 1); g.drawLine(x + w - 1, y, x + w - 1, y + h - 1);
        g.setColor(old);
    }
    public Insets getBorderInsets(Component c) { return new Insets(2, 2, 2, 2); }
}
