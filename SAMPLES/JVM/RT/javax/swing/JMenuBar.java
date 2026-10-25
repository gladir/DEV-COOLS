package javax.swing;
import java.awt.*;
public class JMenuBar extends JComponent {
    public JMenuBar() { setLayout(new FlowLayout(FlowLayout.LEFT, 0, 0)); opaque = true; }
    public JMenu add(JMenu m) { super.add(m); return m; }
    public JMenu getMenu(int i) { return (JMenu) getComponent(i); }
    public int getMenuCount() { return getComponentCount(); }
    protected void paintComponent(Graphics g) { g.setColor(new Color(238, 238, 238)); g.fillRect(0, 0, width, height); g.setColor(new Color(184, 207, 229)); g.drawLine(0, height - 1, width, height - 1); }
}
