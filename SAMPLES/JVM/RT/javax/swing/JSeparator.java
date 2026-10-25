package javax.swing;
import java.awt.*;
public class JSeparator extends JComponent {
    private final int orient;
    public JSeparator() { this(0); }
    public JSeparator(int o) { orient = o; }
    public Dimension getPreferredSize() { return orient == 0 ? new Dimension(0, 2) : new Dimension(2, 0); }
    protected void paintComponent(Graphics g) { g.setColor(new Color(184, 207, 229)); if (orient == 0) g.drawLine(0, 0, width, 0); else g.drawLine(0, 0, 0, height); }
}
