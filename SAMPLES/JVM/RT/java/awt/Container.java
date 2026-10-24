package java.awt;
import java.util.ArrayList;
public class Container extends Component {
    protected ArrayList<Component> comps = new ArrayList<>();
    protected LayoutManager layoutMgr;
    public Container() { }
    public int getComponentCount() { return comps.size(); }
    public Component getComponent(int n) {
        if (n < 0 || n >= comps.size()) throw new ArrayIndexOutOfBoundsException("No such child: " + n);
        return comps.get(n);
    }
    public Component[] getComponents() { return comps.toArray(new Component[0]); }
    public Insets getInsets() { return new Insets(0, 0, 0, 0); }
    public LayoutManager getLayout() { return layoutMgr; }
    public void setLayout(LayoutManager mgr) { layoutMgr = mgr; invalidate(); }
    public Component add(Component comp) { addImpl(comp, null, -1); return comp; }
    public Component add(String name, Component comp) { addImpl(comp, name, -1); return comp; }
    public Component add(Component comp, int index) { addImpl(comp, null, index); return comp; }
    public void add(Component comp, Object constraints) { addImpl(comp, constraints, -1); }
    public void add(Component comp, Object constraints, int index) { addImpl(comp, constraints, index); }
    protected void addImpl(Component comp, Object constraints, int index) {
        if (comp == this) throw new IllegalArgumentException("adding container's parent to itself");
        if (comp.parent != null) comp.parent.remove(comp);
        if (index < 0 || index > comps.size()) comps.add(comp); else comps.add(index, comp);
        comp.parent = this;
        if (layoutMgr instanceof LayoutManager2) ((LayoutManager2) layoutMgr).addLayoutComponent(comp, constraints);
        else if (layoutMgr != null) layoutMgr.addLayoutComponent(constraints instanceof String ? (String) constraints : null, comp);
        invalidate();
        WM.repaint();
    }
    public void remove(Component comp) {
        int i = comps.indexOf(comp);
        if (i >= 0) { comps.remove(i); comp.parent = null; if (layoutMgr != null) layoutMgr.removeLayoutComponent(comp); invalidate(); WM.repaint(); }
    }
    public void remove(int index) { remove(comps.get(index)); }
    public void removeAll() { for (int i = comps.size() - 1; i >= 0; i--) remove(comps.get(i)); }
    public Dimension getPreferredSize() {
        if (prefSize != null) return new Dimension(prefSize);
        if (layoutMgr != null) return layoutMgr.preferredLayoutSize(this);
        return super.getPreferredSize();
    }
    public Dimension getMinimumSize() { if (minSize != null) return new Dimension(minSize); return layoutMgr != null ? layoutMgr.minimumLayoutSize(this) : super.getMinimumSize(); }
    public void doLayout() { if (layoutMgr != null) layoutMgr.layoutContainer(this); }
    protected void doLayoutIfNeeded() { doLayout(); }
    public void invalidate() { super.invalidate(); }
    public void validate() {
        doLayout();
        valid = true;
        for (Component c : new ArrayList<>(comps)) if (c instanceof Container) ((Container) c).validate();
    }
    public Component getComponentAt(int px, int py) {
        if (!contains(px, py)) return null;
        for (int i = 0; i < comps.size(); i++) {
            Component c = comps.get(i);
            if (c.visible && px >= c.x && py >= c.y && px < c.x + c.width && py < c.y + c.height) {
                Component r = c.getComponentAt(px - c.x, py - c.y);
                if (r != null) return r;
            }
        }
        return this;
    }
    public boolean isAncestorOf(Component c) { while (c != null) { if (c == this) return true; c = c.parent; } return false; }
    public void setFont(Font f) { super.setFont(f); }
    public void paint(Graphics g) { paintChildren(g); }
    public void paintComponents(Graphics g) { paintChildren(g); }
    protected void paintChildren(Graphics g) {
        for (int i = comps.size() - 1; i >= 0; i--) {
            Component c = comps.get(i);
            if (!c.visible || c.width <= 0 || c.height <= 0) continue;
            Graphics cg = g.create(c.x, c.y, c.width, c.height);
            c.paint(cg);
            cg.dispose();
        }
    }
    public void addContainerListener(Object l) { }
    public void setFocusCycleRoot(boolean b) { }
}
