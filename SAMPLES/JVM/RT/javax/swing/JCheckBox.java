package javax.swing;
import java.awt.*;
public class JCheckBox extends AbstractButton {
    public JCheckBox() { }
    public JCheckBox(String text) { this.text = text == null ? "" : text; }
    public JCheckBox(String text, boolean sel) { this(text); selected = sel; }
    int extraW() { return 20; }
    int extraH() { return 4; }
    void clicked() { setSelected(!selected); }
    protected void paintComponent(Graphics g) {
        super.paintComponent(g);
        int by = (height - 13) / 2;
        AbstractButton.gradient(g, 3, by + 1, 12, 12, pressed, false);
        g.setColor(new Color(122, 138, 153));
        g.drawRect(2, by, 12, 12);
        if (selected) {
            g.setColor(new Color(51, 51, 51));
            g.drawLine(5, by + 6, 7, by + 9); g.drawLine(6, by + 6, 8, by + 9);
            g.drawLine(8, by + 9, 12, by + 3); g.drawLine(7, by + 9, 11, by + 3);
        }
        FontMetrics fm = g.getFontMetrics(getFont());
        g.setFont(getFont());
        g.setColor(enabled ? new Color(51, 51, 51) : new Color(153, 153, 153));
        g.drawString(text, 20, (height - fm.getHeight()) / 2 + fm.getAscent());
        if (isFocusOwner()) { g.setColor(new Color(99, 130, 191)); g.drawRect(18, (height - fm.getHeight()) / 2 - 1, fm.stringWidth(text) + 2, fm.getHeight() + 1); }
    }
}
