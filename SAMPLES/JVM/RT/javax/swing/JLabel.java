package javax.swing;
import java.awt.*;
public class JLabel extends JComponent implements SwingConstants {
    private String text = "";
    private Icon icon;
    private int hAlign = LEADING, vAlign = CENTER;
    private int gap = 4;
    public int getIconTextGap() { return gap; }
    public void setIconTextGap(int g) { gap = g; invalidate(); repaint(); }
    public JLabel() { }
    public JLabel(String text) { this.text = text == null ? "" : text; }
    public JLabel(String text, int horizontalAlignment) { this(text); hAlign = horizontalAlignment; }
    public JLabel(Icon icon) { this.icon = icon; }
    public JLabel(String text, Icon icon, int ha) { this(text); this.icon = icon; hAlign = ha; }
    public String getText() { return text; }
    public void setText(String t) { text = t == null ? "" : t; invalidate(); repaint(); }
    public Icon getIcon() { return icon; }
    public void setIcon(Icon i) { icon = i; invalidate(); repaint(); }
    public int getHorizontalAlignment() { return hAlign; }
    public void setHorizontalAlignment(int a) { hAlign = a; repaint(); }
    public int getVerticalAlignment() { return vAlign; }
    public void setVerticalAlignment(int a) { vAlign = a; repaint(); }
    public void setHorizontalTextPosition(int p) { }
    public void setVerticalTextPosition(int p) { }
    public void setLabelFor(Component c) { }
    public int getBaseline(int w, int h) {
        if (w < 0 || h < 0) throw new IllegalArgumentException("Width and height must be >= 0");
        if (text.isEmpty() && icon == null) return -1;
        FontMetrics fm = new FontMetrics(getFont());
        Insets in = getInsets();
        int th = Math.max(fm.getHeight(), icon != null ? icon.getIconHeight() : 0);
        int y = in.top + (h - in.top - in.bottom - th) / 2;
        if (vAlign == TOP) y = in.top; else if (vAlign == BOTTOM) y = h - in.bottom - th;
        return y + (th - fm.getHeight()) / 2 + fm.getAscent();
    }
    public BaselineResizeBehavior getBaselineResizeBehavior() { return BaselineResizeBehavior.CENTER_OFFSET; }
    public Dimension getPreferredSize() {
        if (prefSize != null) return new Dimension(prefSize);
        FontMetrics fm = new FontMetrics(getFont());
        Insets in = getInsets();
        int w = fm.stringWidth(text), h = fm.getHeight();
        if (icon != null) { w += icon.getIconWidth() + (text.isEmpty() ? 0 : gap); h = Math.max(h, icon.getIconHeight()); }
        return new Dimension(w + in.left + in.right, h + in.top + in.bottom);
    }
    protected void paintComponent(Graphics g) {
        super.paintComponent(g);
        Insets in = getInsets();
        FontMetrics fm = g.getFontMetrics(getFont());
        g.setFont(getFont());
        int tw = fm.stringWidth(text);
        int iw = icon != null ? icon.getIconWidth() + (text.isEmpty() ? 0 : gap) : 0;
        int total = tw + iw;
        int avail = width - in.left - in.right;
        int x = in.left;
        if (hAlign == CENTER) x += (avail - total) / 2;
        else if (hAlign == RIGHT || hAlign == TRAILING) x += avail - total;
        int th = Math.max(fm.getHeight(), icon != null ? icon.getIconHeight() : 0);
        int y = in.top + (height - in.top - in.bottom - th) / 2;
        if (vAlign == TOP) y = in.top; else if (vAlign == BOTTOM) y = height - in.bottom - th;
        if (icon != null) { icon.paintIcon(this, g, x, y); x += iw; }
        g.setColor(enabled ? new Color(51, 51, 51).equals(getForeground()) || foreground == null ? new Color(51, 51, 51) : getForeground() : new Color(153, 153, 153));
        g.drawString(text, x, y + (th - fm.getHeight()) / 2 + fm.getAscent());
    }
}
