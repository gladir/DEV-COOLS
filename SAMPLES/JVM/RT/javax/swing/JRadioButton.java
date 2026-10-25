package javax.swing;
import java.awt.*;
public class JRadioButton extends AbstractButton {
    public JRadioButton() { }
    public JRadioButton(String text) { this.text = text == null ? "" : text; }
    public JRadioButton(String text, boolean sel) { this(text); selected = sel; }
    int extraW() { return 20; }
    int extraH() { return 4; }
    void clicked() { if (!selected) setSelected(true); }
    protected void paintComponent(Graphics g) {
        super.paintComponent(g);
        int by = (height - 13) / 2;
        g.setColor(Color.WHITE);
        g.fillOval(2, by, 13, 13);
        g.setColor(new Color(122, 138, 153));
        g.drawOval(2, by, 13, 13);
        if (selected) { g.setColor(new Color(51, 51, 51)); g.fillOval(6, by + 4, 5, 5); }
        FontMetrics fm = g.getFontMetrics(getFont());
        g.setFont(getFont());
        g.setColor(enabled ? new Color(51, 51, 51) : new Color(153, 153, 153));
        g.drawString(text, 20, (height - fm.getHeight()) / 2 + fm.getAscent());
    }
}
