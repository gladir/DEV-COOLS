package javax.swing.border;
import java.awt.*;
public class EtchedBorder extends AbstractBorder {
    public static final int RAISED = 0, LOWERED = 1;
    public EtchedBorder() { }
    public EtchedBorder(int t) { }
    public void paintBorder(Component c, Graphics g, int x, int y, int w, int h) {
        Color old = g.getColor();
        g.setColor(new Color(153, 153, 153)); g.drawRect(x, y, w - 2, h - 2);
        g.setColor(Color.WHITE); g.drawRect(x + 1, y + 1, w - 2, h - 2);
        g.setColor(old);
    }
    public Insets getBorderInsets(Component c) { return new Insets(2, 2, 2, 2); }
}
