package java.awt;
public class BorderLayout implements LayoutManager2, java.io.Serializable {
    public static final String NORTH = "North", SOUTH = "South", EAST = "East", WEST = "West", CENTER = "Center";
    public static final String BEFORE_FIRST_LINE = "First", AFTER_LAST_LINE = "Last", BEFORE_LINE_BEGINS = "Before", AFTER_LINE_ENDS = "After";
    public static final String PAGE_START = BEFORE_FIRST_LINE, PAGE_END = AFTER_LAST_LINE, LINE_START = BEFORE_LINE_BEGINS, LINE_END = AFTER_LINE_ENDS;
    int hgap, vgap;
    Component north, west, east, south, center;
    public BorderLayout() { this(0, 0); }
    public BorderLayout(int hgap, int vgap) { this.hgap = hgap; this.vgap = vgap; }
    public int getHgap() { return hgap; }
    public int getVgap() { return vgap; }
    public void setHgap(int h) { hgap = h; }
    public void setVgap(int v) { vgap = v; }
    public void addLayoutComponent(Component comp, Object constraints) {
        if ((constraints == null) || (constraints instanceof String)) addLayoutComponent((String) constraints, comp);
        else throw new IllegalArgumentException("cannot add to layout: constraint must be a string (or null)");
    }
    public void addLayoutComponent(String name, Component comp) {
        if (name == null) name = "Center";
        if ("Center".equals(name)) center = comp;
        else if ("North".equals(name) || "First".equals(name)) north = comp;
        else if ("South".equals(name) || "Last".equals(name)) south = comp;
        else if ("East".equals(name) || "After".equals(name)) east = comp;
        else if ("West".equals(name) || "Before".equals(name)) west = comp;
        else throw new IllegalArgumentException("cannot add to layout: unknown constraint: " + name);
    }
    public void removeLayoutComponent(Component comp) {
        if (comp == center) center = null; else if (comp == north) north = null; else if (comp == south) south = null;
        else if (comp == east) east = null; else if (comp == west) west = null;
    }
    public Dimension minimumLayoutSize(Container target) { return preferredLayoutSize(target); }
    public Dimension preferredLayoutSize(Container target) {
        Dimension dim = new Dimension(0, 0);
        Component c;
        if ((c = east) != null && c.isVisible()) { Dimension d = c.getPreferredSize(); dim.width += d.width + hgap; dim.height = Math.max(d.height, dim.height); }
        if ((c = west) != null && c.isVisible()) { Dimension d = c.getPreferredSize(); dim.width += d.width + hgap; dim.height = Math.max(d.height, dim.height); }
        if ((c = center) != null && c.isVisible()) { Dimension d = c.getPreferredSize(); dim.width += d.width; dim.height = Math.max(d.height, dim.height); }
        if ((c = north) != null && c.isVisible()) { Dimension d = c.getPreferredSize(); dim.width = Math.max(d.width, dim.width); dim.height += d.height + vgap; }
        if ((c = south) != null && c.isVisible()) { Dimension d = c.getPreferredSize(); dim.width = Math.max(d.width, dim.width); dim.height += d.height + vgap; }
        Insets insets = target.getInsets();
        dim.width += insets.left + insets.right;
        dim.height += insets.top + insets.bottom;
        return dim;
    }
    public Dimension maximumLayoutSize(Container target) { return new Dimension(Integer.MAX_VALUE, Integer.MAX_VALUE); }
    public float getLayoutAlignmentX(Container parent) { return 0.5f; }
    public float getLayoutAlignmentY(Container parent) { return 0.5f; }
    public void invalidateLayout(Container target) { }
    public void layoutContainer(Container target) {
        Insets insets = target.getInsets();
        int top = insets.top;
        int bottom = target.getHeight() - insets.bottom;
        int left = insets.left;
        int right = target.getWidth() - insets.right;
        Component c;
        if ((c = north) != null && c.isVisible()) {
            c.setSize(right - left, c.getHeight());
            Dimension d = c.getPreferredSize();
            c.setBounds(left, top, right - left, d.height);
            top += d.height + vgap;
        }
        if ((c = south) != null && c.isVisible()) {
            Dimension d = c.getPreferredSize();
            c.setBounds(left, bottom - d.height, right - left, d.height);
            bottom -= d.height + vgap;
        }
        if ((c = east) != null && c.isVisible()) {
            Dimension d = c.getPreferredSize();
            c.setBounds(right - d.width, top, d.width, bottom - top);
            right -= d.width + hgap;
        }
        if ((c = west) != null && c.isVisible()) {
            Dimension d = c.getPreferredSize();
            c.setBounds(left, top, d.width, bottom - top);
            left += d.width + hgap;
        }
        if ((c = center) != null && c.isVisible()) c.setBounds(left, top, right - left, bottom - top);
    }
    public String toString() { return getClass().getName() + "[hgap=" + hgap + ",vgap=" + vgap + "]"; }
}
