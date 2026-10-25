package javax.swing.border;
import java.awt.*;
public class TitledBorder extends AbstractBorder {
    protected String title;
    public TitledBorder(String title) { this.title = title; }
    public String getTitle() { return title; }
    public void paintBorder(Component c, Graphics g, int x, int y, int w, int h) {
        Color old = g.getColor();
        FontMetrics fm = g.getFontMetrics(c.getFont());
        int ty = y + fm.getHeight() / 2;
        g.setColor(new Color(153, 153, 153));
        g.drawRect(x + 1, ty, w - 3, h - ty - 2);
        g.setColor(c.getBackground());
        int tw = fm.stringWidth(title);
        g.fillRect(x + 8, y, tw + 4, fm.getHeight());
        g.setColor(new Color(51, 51, 51));
        g.setFont(c.getFont());
        g.drawString(title, x + 10, y + fm.getAscent());
        g.setColor(old);
    }
    public Insets getBorderInsets(Component c) { FontMetrics fm = new FontMetrics(c.getFont()); return new Insets(fm.getHeight() + 2, 6, 6, 6); }
}
