package javax.swing;
import java.awt.*;
public class JProgressBar extends JComponent {
    private int min, max = 100, value;
    private boolean str;
    public JProgressBar() { }
    public JProgressBar(int min, int max) { this.min = min; this.max = max; }
    public void setValue(int v) { value = Math.max(min, Math.min(max, v)); repaint(); }
    public int getValue() { return value; }
    public void setMinimum(int m) { min = m; }
    public void setMaximum(int m) { max = m; }
    public int getMaximum() { return max; }
    public int getMinimum() { return min; }
    public void setStringPainted(boolean b) { str = b; }
    public void setIndeterminate(boolean b) { }
    public Dimension getPreferredSize() { return prefSize != null ? new Dimension(prefSize) : new Dimension(146, 19); }
    protected void paintComponent(Graphics g) {
        g.setColor(Color.WHITE); g.fillRect(0, 0, width, height);
        int w = (width - 2) * (value - min) / Math.max(1, max - min);
        AbstractButton.gradient(g, 1, 1, w, height - 2, false, false);
        g.setColor(new Color(122, 138, 153)); g.drawRect(0, 0, width - 1, height - 1);
        if (str) { FontMetrics fm = g.getFontMetrics(getFont()); String s = (100 * (value - min) / Math.max(1, max - min)) + "%"; g.setColor(new Color(51, 51, 51)); g.drawString(s, (width - fm.stringWidth(s)) / 2, (height - fm.getHeight()) / 2 + fm.getAscent()); }
    }
}
