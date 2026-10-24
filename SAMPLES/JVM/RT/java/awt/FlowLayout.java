package java.awt;
public class FlowLayout implements LayoutManager, java.io.Serializable {
    public static final int LEFT = 0, CENTER = 1, RIGHT = 2, LEADING = 3, TRAILING = 4;
    int align, hgap, vgap;
    public FlowLayout() { this(CENTER, 5, 5); }
    public FlowLayout(int align) { this(align, 5, 5); }
    public FlowLayout(int align, int hgap, int vgap) { this.align = align; this.hgap = hgap; this.vgap = vgap; }
    public int getAlignment() { return align; }
    public void setAlignment(int a) { align = a; }
    public int getHgap() { return hgap; }
    public int getVgap() { return vgap; }
    public void setHgap(int h) { hgap = h; }
    public void setVgap(int v) { vgap = v; }
    public void addLayoutComponent(String name, Component comp) { }
    public void removeLayoutComponent(Component comp) { }
    public Dimension preferredLayoutSize(Container target) {
        int w = 0, h = 0, n = 0;
        for (int i = 0; i < target.getComponentCount(); i++) {
            Component m = target.getComponent(i);
            if (m.isVisible()) {
                Dimension d = m.getPreferredSize();
                h = Math.max(h, d.height);
                if (n > 0) w += hgap;
                w += d.width; n++;
            }
        }
        Insets in = target.getInsets();
        return new Dimension(w + in.left + in.right + hgap * 2, h + in.top + in.bottom + vgap * 2);
    }
    public Dimension minimumLayoutSize(Container target) { return preferredLayoutSize(target); }
    public void layoutContainer(Container target) {
        Insets in = target.getInsets();
        int maxwidth = target.getWidth() - (in.left + in.right + hgap * 2);
        int x = 0, y = in.top + vgap, rowh = 0, start = 0;
        int nmembers = target.getComponentCount();
        for (int i = 0; i < nmembers; i++) {
            Component m = target.getComponent(i);
            if (!m.isVisible()) continue;
            Dimension d = m.getPreferredSize();
            m.setSize(d.width, d.height);
            if ((x == 0) || ((x + d.width) <= maxwidth)) {
                if (x > 0) x += hgap;
                x += d.width;
                rowh = Math.max(rowh, d.height);
            } else {
                rowh = moveComponents(target, in.left + hgap, y, maxwidth - x, rowh, start, i);
                x = d.width; y += vgap + rowh; rowh = d.height; start = i;
            }
        }
        moveComponents(target, in.left + hgap, y, maxwidth - x, rowh, start, nmembers);
    }
    private int moveComponents(Container target, int x, int y, int width, int height, int rowStart, int rowEnd) {
        switch (align) {
            case LEFT: case LEADING: break;
            case CENTER: x += width / 2; break;
            case RIGHT: case TRAILING: x += width; break;
        }
        for (int i = rowStart; i < rowEnd; i++) {
            Component m = target.getComponent(i);
            if (m.isVisible()) { m.setLocation(x, y + (height - m.getHeight()) / 2); x += m.getWidth() + hgap; }
        }
        return height;
    }
    public String toString() { return getClass().getName() + "[hgap=" + hgap + ",vgap=" + vgap + ",align=" + (align == 0 ? "left" : align == 1 ? "center" : "right") + "]"; }
}
