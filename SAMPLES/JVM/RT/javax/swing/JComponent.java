package javax.swing;
import java.awt.*;
import javax.swing.border.Border;
public abstract class JComponent extends Container {
    protected Border border;
    protected boolean opaque = false;
    String toolTip;
    public JComponent() { }
    public void setBorder(Border b) { border = b; invalidate(); repaint(); }
    public Border getBorder() { return border; }
    public Insets getInsets() { return border != null ? border.getBorderInsets(this) : new Insets(0, 0, 0, 0); }
    public boolean isOpaque() { return opaque; }
    public void setOpaque(boolean b) { opaque = b; repaint(); }
    public void setToolTipText(String t) { toolTip = t; }
    public String getToolTipText() { return toolTip; }
    public void setDoubleBuffered(boolean b) { }
    public void setAlignmentX(float f) { }
    public void setAlignmentY(float f) { }
    public void setInheritsPopupMenu(boolean b) { }
    public Object getClientProperty(Object k) { return null; }
    public void putClientProperty(Object k, Object v) { }
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
        Insets in = new Insets(0, 0, 0, 0);
        super.paintChildren(g);
    }
    public void paint(Graphics g) {
        paintComponent(g);
        paintBorder(g);
        paintChildren(g);
    }
    public void update(Graphics g) { paint(g); }
    public void paintImmediately(int x, int y, int w, int h) { }
    public void scrollRectToVisible(Rectangle r) { }
    public void grabFocus() { requestFocus(); }
    public void setNextFocusableComponent(Component c) { }
    public JRootPane getRootPane() { return null; }
}
