package javax.swing;
import java.awt.*;
import java.beans.*;
import java.util.HashMap;
import javax.swing.border.Border;
public abstract class JComponent extends Container {
    protected Border border;
    protected boolean opaque = false;
    String toolTip;
    private HashMap<Object, Object> clientProps;
    private PropertyChangeSupport pcs;
    private boolean autoscrolls;
    public JComponent() { }
    public void setBorder(Border b) { Border old = border; border = b; invalidate(); repaint(); firePropertyChange("border", old, b); }
    public Border getBorder() { return border; }
    public Insets getInsets() { return border != null ? border.getBorderInsets(this) : new Insets(0, 0, 0, 0); }
    public boolean isOpaque() { return opaque; }
    public void setOpaque(boolean b) { boolean old = opaque; opaque = b; repaint(); firePropertyChange("opaque", old, b); }
    public void setToolTipText(String t) { toolTip = t; }
    public String getToolTipText() { return toolTip; }
    public void setDoubleBuffered(boolean b) { }
    public void setAlignmentX(float f) { }
    public void setAlignmentY(float f) { }
    public void setInheritsPopupMenu(boolean b) { }
    public void setAutoscrolls(boolean b) { autoscrolls = b; }
    public boolean getAutoscrolls() { return autoscrolls; }
    public final Object getClientProperty(Object k) { return clientProps == null ? null : clientProps.get(k); }
    public final void putClientProperty(Object k, Object v) {
        Object old = getClientProperty(k);
        if (v == null) { if (clientProps != null) clientProps.remove(k); }
        else { if (clientProps == null) clientProps = new HashMap<>(); clientProps.put(k, v); }
        firePropertyChange(k.toString(), old, v);
    }
    public void addPropertyChangeListener(PropertyChangeListener l) { if (pcs == null) pcs = new PropertyChangeSupport(this); pcs.addPropertyChangeListener(l); }
    public void addPropertyChangeListener(String name, PropertyChangeListener l) { if (pcs == null) pcs = new PropertyChangeSupport(this); pcs.addPropertyChangeListener(name, l); }
    public void removePropertyChangeListener(PropertyChangeListener l) { if (pcs != null) pcs.removePropertyChangeListener(l); }
    public void removePropertyChangeListener(String name, PropertyChangeListener l) { if (pcs != null) pcs.removePropertyChangeListener(name, l); }
    public PropertyChangeListener[] getPropertyChangeListeners() { return pcs == null ? new PropertyChangeListener[0] : pcs.getPropertyChangeListeners(); }
    protected void firePropertyChange(String name, Object o, Object n) { if (pcs != null) pcs.firePropertyChange(name, o, n); }
    public void firePropertyChange(String name, boolean o, boolean n) { if (pcs != null) pcs.firePropertyChange(name, o, n); }
    public void firePropertyChange(String name, int o, int n) { if (pcs != null) pcs.firePropertyChange(name, o, n); }
    public void setComponentPopupMenu(Object p) { }
    public void registerKeyboardAction(Object a, Object b, Object c) { }
    public javax.swing.InputMap getInputMap() { return new javax.swing.InputMap(); }
    public javax.swing.InputMap getInputMap(int c) { return new javax.swing.InputMap(); }
    public javax.swing.ActionMap getActionMap() { return new javax.swing.ActionMap(); }
    public Dimension getPreferredSize() {
        if (prefSize != null) return new Dimension(prefSize);
        Dimension d = super.getPreferredSize();
        return d;
    }
    protected void paintComponent(Graphics g) {
        if (opaque) { g.setColor(getBackground()); g.fillRect(0, 0, width, height); }
    }
    protected void paintBorder(Graphics g) { if (border != null) border.paintBorder(this, g, 0, 0, width, height); }
    protected void paintChildren(Graphics g) {
        super.paintChildren(g);
    }
    public void paint(Graphics g) {
        paintComponent(g);
        paintBorder(g);
        paintChildren(g);
    }
    public void update(Graphics g) { paint(g); }
    public void paintImmediately(int x, int y, int w, int h) { }
    public void scrollRectToVisible(Rectangle r) {
        if (parent instanceof JComponent) ((JComponent) parent).scrollRectToVisible(new Rectangle(r.x + x, r.y + y, r.width, r.height));
    }
    public Rectangle getVisibleRect() {
        int l = 0, t = 0, r = width, b = height;
        Component c = this;
        while (c.getParent() != null && !(c.getParent() instanceof Window)) {
            Container p = c.getParent();
            l += c.getX(); t += c.getY(); r += c.getX(); b += c.getY();
            if (l < 0) l = 0;
            if (t < 0) t = 0;
            if (r > p.getWidth()) r = p.getWidth();
            if (b > p.getHeight()) b = p.getHeight();
            if (r <= l || b <= t) return new Rectangle(0, 0, 0, 0);
            c = p;
        }
        // retour aux coordonnees de ce composant
        int ox = 0, oy = 0;
        Component k = this;
        while (k.getParent() != null && !(k.getParent() instanceof Window)) { ox += k.getX(); oy += k.getY(); k = k.getParent(); }
        return new Rectangle(l - ox, t - oy, r - l, b - t);
    }
    public void grabFocus() { requestFocus(); }
    public void setNextFocusableComponent(Component c) { }
    public JRootPane getRootPane() { return null; }
    public static void attach(Component c, Container owner) { if (c instanceof JComponent) ((JComponent) c).parent = owner; }
    /** peint un composant de rendu (cellule) dans le rectangle donne sans l'ajouter a la hierarchie */
    public static void paintCell(Graphics g, Component c, Container owner, int cx, int cy, int cw, int ch) {
        if (c instanceof JComponent) {
            JComponent j = (JComponent) c;
            j.parent = owner;
            j.x = 0; j.y = 0; j.width = cw; j.height = ch;
            if (j.getComponentCount() > 0) j.doLayout();
        }
        Graphics cg = g.create(cx, cy, cw, ch);
        c.paint(cg);
        cg.dispose();
    }
}
