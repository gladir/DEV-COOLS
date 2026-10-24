package javax.swing;
import java.awt.*;
public class JPanel extends JComponent {
    public JPanel() { this(new FlowLayout()); opaque = true; }
    public JPanel(LayoutManager layout) { setLayout(layout); opaque = true; }
    public JPanel(boolean doubleBuffered) { this(); }
    public JPanel(LayoutManager layout, boolean db) { this(layout); }
}
