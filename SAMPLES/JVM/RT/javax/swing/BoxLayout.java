package javax.swing;
import java.awt.*;
public class BoxLayout implements LayoutManager2 {
    public static final int X_AXIS = 0, Y_AXIS = 1, LINE_AXIS = 2, PAGE_AXIS = 3;
    private final Container target;
    private final int axis;
    public BoxLayout(Container target, int axis) { this.target = target; this.axis = axis == LINE_AXIS ? X_AXIS : axis == PAGE_AXIS ? Y_AXIS : axis; }
    public void addLayoutComponent(String name, Component comp) { }
    public void addLayoutComponent(Component comp, Object constraints) { }
    public void removeLayoutComponent(Component comp) { }
    public Dimension preferredLayoutSize(Container parent) {
        int w = 0, h = 0;
        for (int i = 0; i < parent.getComponentCount(); i++) {
            Component c = parent.getComponent(i);
            if (!c.isVisible()) continue;
            Dimension d = c.getPreferredSize();
            if (axis == X_AXIS) { w += d.width; h = Math.max(h, d.height); } else { h += d.height; w = Math.max(w, d.width); }
        }
        Insets in = parent.getInsets();
        return new Dimension(w + in.left + in.right, h + in.top + in.bottom);
    }
    public Dimension minimumLayoutSize(Container parent) { return preferredLayoutSize(parent); }
    public Dimension maximumLayoutSize(Container target) { return new Dimension(Integer.MAX_VALUE, Integer.MAX_VALUE); }
    public float getLayoutAlignmentX(Container target) { return 0.5f; }
    public float getLayoutAlignmentY(Container target) { return 0.5f; }
    public void invalidateLayout(Container target) { }
    public void layoutContainer(Container parent) {
        Insets in = parent.getInsets();
        int x = in.left, y = in.top;
        int aw = parent.getWidth() - in.left - in.right, ah = parent.getHeight() - in.top - in.bottom;
        int n = parent.getComponentCount();
        int glue = 0, fixed = 0;
        for (int i = 0; i < n; i++) {
            Component c = parent.getComponent(i);
            if (!c.isVisible()) continue;
            if (c instanceof Box.Filler f && f.glue) glue++;
            else fixed += axis == X_AXIS ? c.getPreferredSize().width : c.getPreferredSize().height;
        }
        int extra = glue > 0 ? Math.max(0, (axis == X_AXIS ? aw : ah) - fixed) / glue : 0;
        for (int i = 0; i < n; i++) {
            Component c = parent.getComponent(i);
            if (!c.isVisible()) continue;
            Dimension d = c.getPreferredSize();
            boolean g = c instanceof Box.Filler f2 && f2.glue;
            if (axis == X_AXIS) { int w = g ? extra : d.width; c.setBounds(x, y, w, Math.min(ah, Math.max(d.height, ah))); x += w; }
            else { int h = g ? extra : d.height; c.setBounds(x, y, Math.min(aw, Math.max(d.width, aw)), h); y += h; }
        }
    }
}
