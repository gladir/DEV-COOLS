package java.awt;
import java.util.*;
public class CardLayout implements LayoutManager2 {
    private final Map<String, Component> cards = new LinkedHashMap<>();
    private int hgap, vgap;
    private Component current;
    public CardLayout() { }
    public CardLayout(int hgap, int vgap) { this.hgap = hgap; this.vgap = vgap; }
    public void addLayoutComponent(Component comp, Object constraints) { addLayoutComponent((String) constraints, comp); }
    public void addLayoutComponent(String name, Component comp) {
        cards.put(name, comp);
        comp.setVisible(false);
        if (current == null) { current = comp; comp.setVisible(true); }
    }
    public void removeLayoutComponent(Component comp) { cards.values().remove(comp); }
    public void show(Container parent, String name) {
        Component c = cards.get(name);
        if (c == null) return;
        for (Component k : cards.values()) k.setVisible(false);
        c.setVisible(true); current = c;
        parent.validate(); parent.repaint();
    }
    public void next(Container parent) { move(parent, 1); }
    public void previous(Container parent) { move(parent, -1); }
    public void first(Container parent) { if (!cards.isEmpty()) show(parent, cards.keySet().iterator().next()); }
    public void last(Container parent) { String l = null; for (String k : cards.keySet()) l = k; if (l != null) show(parent, l); }
    private void move(Container parent, int d) {
        java.util.List<String> names = new ArrayList<>(cards.keySet());
        int i = 0;
        for (int k = 0; k < names.size(); k++) if (cards.get(names.get(k)) == current) i = k;
        if (names.isEmpty()) return;
        i = (i + d + names.size()) % names.size();
        show(parent, names.get(i));
    }
    public Dimension preferredLayoutSize(Container parent) {
        int w = 0, h = 0;
        for (Component c : cards.values()) { Dimension d = c.getPreferredSize(); w = Math.max(w, d.width); h = Math.max(h, d.height); }
        Insets in = parent.getInsets();
        return new Dimension(w + in.left + in.right + hgap * 2, h + in.top + in.bottom + vgap * 2);
    }
    public Dimension minimumLayoutSize(Container parent) { return preferredLayoutSize(parent); }
    public Dimension maximumLayoutSize(Container target) { return new Dimension(Integer.MAX_VALUE, Integer.MAX_VALUE); }
    public float getLayoutAlignmentX(Container parent) { return 0.5f; }
    public float getLayoutAlignmentY(Container parent) { return 0.5f; }
    public void invalidateLayout(Container target) { }
    public void layoutContainer(Container parent) {
        Insets in = parent.getInsets();
        for (Component c : cards.values()) c.setBounds(in.left + hgap, in.top + vgap, parent.getWidth() - (in.left + in.right + hgap * 2), parent.getHeight() - (in.top + in.bottom + vgap * 2));
    }
}
