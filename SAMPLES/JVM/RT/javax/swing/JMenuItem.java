package javax.swing;
import java.awt.*;
public class JMenuItem extends AbstractButton {
    public JMenuItem() { }
    public JMenuItem(String text) { this.text = text; }
    public void setAccelerator(Object k) { }
    int extraW() { return 36; }
    int extraH() { return 6; }
    protected void paintComponent(Graphics g) {
        if (text == null) { g.setColor(new Color(184, 207, 229)); g.drawLine(2, height / 2, width - 3, height / 2); return; }
        if (hovered) { g.setColor(new Color(184, 207, 229)); g.fillRect(0, 0, width, height); }
        FontMetrics fm = g.getFontMetrics(getFont());
        g.setFont(getFont());
        g.setColor(enabled ? new Color(51, 51, 51) : new Color(153, 153, 153));
        g.drawString(text, 18, (height - fm.getHeight()) / 2 + fm.getAscent());
    }
}
