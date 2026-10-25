package javax.swing;
import java.awt.*;
import java.awt.event.*;
public class JButton extends AbstractButton {
    public JButton() { }
    public JButton(String text) { this.text = text == null ? "" : text; }
    public JButton(Icon icon) { this.icon = icon; }
    public JButton(String text, Icon icon) { this.text = text; this.icon = icon; }
    int extraW() { return 28; }
    int extraH() { return 14; }
    public boolean isDefaultButton() { return false; }
    protected void paintComponent(Graphics g) {
        if (contentAreaFilled) {
            Color bord = new Color(122, 138, 153);
            boolean hov = hovered && enabled;
            if (enabled) gradient(g, 1, 1, width - 2, height - 2, pressed, hov);
            else { g.setColor(new Color(238, 238, 238)); g.fillRect(1, 1, width - 2, height - 2); }
            g.setColor(enabled ? bord : new Color(184, 184, 184));
            g.drawLine(2, 0, width - 3, 0); g.drawLine(2, height - 1, width - 3, height - 1);
            g.drawLine(0, 2, 0, height - 3); g.drawLine(width - 1, 2, width - 1, height - 3);
            g.drawLine(1, 1, 1, 1); g.drawLine(width - 2, 1, width - 2, 1); g.drawLine(1, height - 2, 1, height - 2); g.drawLine(width - 2, height - 2, width - 2, height - 2);
            g.setColor(new Color(238, 238, 238));
            g.drawLine(0, 0, 1, 0); g.drawLine(0, 0, 0, 1);
            g.drawLine(width - 1, 0, width - 2, 0); g.drawLine(width - 1, 0, width - 1, 1);
            g.drawLine(0, height - 1, 1, height - 1); g.drawLine(0, height - 1, 0, height - 2);
            g.drawLine(width - 1, height - 1, width - 2, height - 1); g.drawLine(width - 1, height - 1, width - 1, height - 2);
        }
        FontMetrics fm = g.getFontMetrics(getFont());
        g.setFont(getFont());
        int tw = fm.stringWidth(text);
        int iw = icon != null ? icon.getIconWidth() + (text.isEmpty() ? 0 : 4) : 0;
        int x = (width - tw - iw) / 2;
        int off = pressed ? 1 : 0;
        if (icon != null) { icon.paintIcon(this, g, x + off, (height - icon.getIconHeight()) / 2 + off); x += iw; }
        g.setColor(enabled ? (foreground != null ? foreground : new Color(51, 51, 51)) : new Color(153, 153, 153));
        g.drawString(text, x + off, (height - fm.getHeight()) / 2 + fm.getAscent() + off);
        if (focusPainted && isFocusOwner() && enabled) {
            g.setColor(new Color(99, 130, 191));
            g.drawRect(3, 3, width - 7, height - 7);
        }
    }
}
